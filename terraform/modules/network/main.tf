# -----------------------------------------------------------------------------
# VPC with one regional subnet for GKE nodes, plus secondary ranges for
# Pods and Services (VPC-native / alias IPs).
# Nodes are private (no external IPs), so Cloud NAT provides egress for
# pulling public images (Docker Hub, quay.io, ghcr.io, ...).
# -----------------------------------------------------------------------------

resource "google_compute_network" "this" {
  #checkov:skip=CKV2_GCP_18:Firewall is defined (deny_all_ingress); Checkov's graph check doesn't follow module wiring
  name                            = "${var.name_prefix}-vpc"
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.name_prefix}-nodes"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.nodes_cidr
  private_ip_google_access = true # reach Google APIs (Artifact Registry, Logging...) without public IPs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  # VPC flow logs are useful for security investigations but cost money
  # (log ingestion). Off by default; flip the variable for a demo.
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name_prefix}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Explicit default-deny for ingress, documented and logged. GKE creates its
# own allow rules (control plane, LB health checks) at priority 1000, which
# win over this rule.
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.name_prefix}-deny-all-ingress"
  project   = var.project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}

# Static external IP for the APISIX LoadBalancer Service (used on Day 4).
# A stable IP means stable DNS / nip.io hostnames across redeploys.
resource "google_compute_address" "ingress" {
  name         = "${var.name_prefix}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}
