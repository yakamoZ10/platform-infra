# -----------------------------------------------------------------------------
# DEV ENVIRONMENT - applied by CI (GitHub Actions) after the first manual run.
# Safe to destroy and rebuild: nothing here is "un-deletable".
# -----------------------------------------------------------------------------

locals {
  name_prefix = "platform-${var.environment}"

  labels = {
    managed-by  = "terraform"
    environment = var.environment
    project     = "platform"
  }
}

# Outputs of the bootstrap layer (KMS key, CI service accounts).
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "bootstrap"
  }
}

module "network" {
  source = "../../modules/network"

  project_id       = var.project_id
  region           = var.region
  name_prefix      = local.name_prefix
  enable_flow_logs = var.enable_flow_logs
}

module "gke" {
  source = "../../modules/gke"

  project_id   = var.project_id
  zone         = var.zone
  cluster_name = local.name_prefix

  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  admin_cidrs             = var.admin_cidrs
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  database_encryption_key = data.terraform_remote_state.bootstrap.outputs.gke_secrets_key_id
  deletion_protection     = var.deletion_protection

  machine_type      = var.machine_type
  system_node_count = var.system_node_count
  spot_min_nodes    = var.spot_min_nodes
  spot_max_nodes    = var.spot_max_nodes

  # CI's terraform-apply SA must be able to attach the node SA to node pools.
  node_sa_users = ["serviceAccount:${data.terraform_remote_state.bootstrap.outputs.tf_apply_sa_email}"]

  labels = local.labels
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = "platform"
  labels        = local.labels

  reader_members = ["serviceAccount:${module.gke.node_service_account_email}"]
  writer_members = ["serviceAccount:${data.terraform_remote_state.bootstrap.outputs.ci_apps_sa_email}"]
}

module "secrets" {
  source = "../../modules/secrets"

  project_id    = var.project_id
  region        = var.region
  workload_pool = module.gke.workload_pool
  labels        = local.labels

  secret_ids = [
    "keycloak-admin-password",
    "keycloak-db-password",
    "grafana-admin-password",
    "apisix-admin-key",
  ]
}
