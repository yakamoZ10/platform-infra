# -----------------------------------------------------------------------------
# Hardened zonal GKE Standard cluster
#
#  - Private nodes (no external IPs), public control-plane endpoint locked to
#    admin CIDRs via master authorized networks
#  - Dataplane V2 (eBPF/Cilium): native NetworkPolicy enforcement
#  - Workload Identity: pods get GCP identities, no service account keys
#  - Application-layer secrets encryption with a customer-managed KMS key
#  - Shielded nodes + secure boot, COS containerd, least-privilege node SA
#  - Two node pools: small on-demand "system" pool + autoscaled Spot pool
# -----------------------------------------------------------------------------

locals {
  workload_pool = "${var.project_id}.svc.id.goog"
}

# ---------------------------------------------------------------------------
# Least-privilege node service account (instead of the Compute default SA,
# which has the very broad Editor role).
# ---------------------------------------------------------------------------
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE nodes for ${var.cluster_name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/autoscaling.metricsWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# Principals allowed to "act as" the node SA (needed to create/upgrade node
# pools). Granted on this one SA instead of project-wide serviceAccountUser.
resource "google_service_account_iam_member" "node_sa_users" {
  for_each = toset(var.node_sa_users)

  service_account_id = google_service_account.nodes.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  #checkov:skip=CKV_GCP_12:NetworkPolicy is enforced natively by Dataplane V2 (datapath_provider = ADVANCED_DATAPATH)
  #checkov:skip=CKV_GCP_69:GKE metadata server is set on every node pool; the default pool is removed at creation
  #checkov:skip=CKV_GCP_61:Flow logs / intranode visibility off to save log-ingestion cost (toggle: enable_flow_logs)
  #checkov:skip=CKV_GCP_65:Google Groups for RBAC requires a Workspace/Cloud Identity organization
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone # zonal = 1 control plane, covered by the GKE free tier

  # We manage node pools separately; GKE requires a default pool at creation
  # time, so create a tiny one and delete it immediately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Off for this project so `terraform destroy` works for the rebuild test.
  # In production: true.
  deletion_protection = var.deletion_protection

  network         = var.network_id
  subnetwork      = var.subnet_id
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Dataplane V2 = eBPF (Cilium). Enforces NetworkPolicy natively, so the
  # legacy Calico `network_policy` block must NOT be set.
  datapath_provider = "ADVANCED_DATAPATH"

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # keep a public endpoint, but restricted below
    # Leave null on new GKE versions (Private Service Connect based control plane).
    # Fallback if the API complains: set to e.g. "172.16.0.0/28".
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false

    dynamic "cidr_blocks" {
      for_each = var.admin_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "admin-${cidr_blocks.key}"
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = local.workload_pool
  }

  # Envelope-encrypt Kubernetes Secrets in etcd with our own KMS key (CMEK).
  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.database_encryption_key
  }

  enable_shielded_nodes = true

  # No legacy client-certificate auth; access only via IAM (gcloud auth).
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Binary Authorization in project-policy mode. The default project policy
  # allows all images; tighten it later (e.g. only images from our registry).
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Free GKE security posture dashboard (config + OS vulnerability findings).
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    dns_cache_config {
      enabled = true # NodeLocal DNSCache: fewer kube-dns hops, lower latency
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  cluster_autoscaling {
    enabled             = false # no node auto-provisioning; we define pools ourselves
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

  # GKE cost allocation (per-namespace/label cost breakdown in billing).
  cost_management_config {
    enabled = true
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # We run our own kube-prometheus-stack later, so Google Managed Prometheus
  # is disabled to save node resources.
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time # UTC, 4h window
    }
  }

  resource_labels = var.labels

  depends_on = [google_project_iam_member.nodes]
}

# ---------------------------------------------------------------------------
# Node pools
#
# Free-trial accounts are capped at 8 vCPUs. 1 system + max 3 spot nodes of
# e2-standard-2 = 8 vCPU, so surge upgrades are disabled (max_surge = 0)
# to never need a 9th/10th vCPU during upgrades.
# ---------------------------------------------------------------------------
locals {
  base_node_config = {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
  }
}

resource "google_container_node_pool" "system" {
  name     = "system"
  project  = var.project_id
  location = var.zone
  cluster  = google_container_cluster.this.name

  node_count = var.system_node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 0
    max_unavailable = 1
  }

  node_config {
    machine_type    = local.base_node_config.machine_type
    disk_size_gb    = local.base_node_config.disk_size_gb
    disk_type       = local.base_node_config.disk_type
    image_type      = local.base_node_config.image_type
    spot            = false
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"] # access is controlled by IAM, not scopes

    labels = merge(var.labels, { pool = "system" })
    tags   = ["gke-${var.cluster_name}", "gke-${var.cluster_name}-system"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA" # required for Workload Identity, hides node metadata
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

resource "google_container_node_pool" "spot" {
  name     = "spot"
  project  = var.project_id
  location = var.zone
  cluster  = google_container_cluster.this.name

  initial_node_count = var.spot_min_nodes

  autoscaling {
    min_node_count  = var.spot_min_nodes
    max_node_count  = var.spot_max_nodes
    location_policy = "ANY" # best for Spot: pick whatever capacity is available
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 0
    max_unavailable = 1
  }

  node_config {
    machine_type    = local.base_node_config.machine_type
    disk_size_gb    = local.base_node_config.disk_size_gb
    disk_type       = local.base_node_config.disk_type
    image_type      = local.base_node_config.image_type
    spot            = true # ~60-90% cheaper, can be preempted with 30s notice
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # GKE also adds cloud.google.com/gke-spot=true automatically.
    labels = merge(var.labels, { pool = "spot" })
    tags   = ["gke-${var.cluster_name}", "gke-${var.cluster_name}-spot"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    # Autoscaler (and the sleep/wake scripts) change the live node count.
    ignore_changes = [initial_node_count]
  }
}
