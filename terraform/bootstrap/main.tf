# -----------------------------------------------------------------------------
# BOOTSTRAP LAYER - applied once, manually, by a human with Owner rights.
#
# Contains everything that
#   a) the CI pipeline needs before it can run (WIF, CI service accounts), or
#   b) cannot be deleted/recreated cleanly (KMS keys, WIF pool IDs).
#
# envs/* are applied by CI and can be destroyed/rebuilt at any time.
# -----------------------------------------------------------------------------

locals {
  labels = {
    managed-by = "terraform"
    layer      = "bootstrap"
    project    = "platform"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  # Never disable APIs on destroy - that breaks every other resource.
  disable_on_destroy         = false
  disable_dependent_services = false
}

module "github_wif" {
  source = "../modules/github-wif"

  project_id   = var.project_id
  github_owner = var.github_owner
  infra_repo   = var.infra_repo
  apps_repo    = var.apps_repo
  state_bucket = var.state_bucket

  depends_on = [google_project_service.apis]
}

module "kms" {
  source = "../modules/kms"

  project_id = var.project_id
  region     = var.region
  labels     = local.labels

  depends_on = [google_project_service.apis]
}
