# -----------------------------------------------------------------------------
# Keyless GitHub Actions -> GCP authentication (Workload Identity Federation).
#
# GitHub issues a short-lived OIDC token per workflow run; GCP exchanges it for
# a short-lived access token of a service account. No JSON keys anywhere.
#
# Three identities, least privilege:
#   ci-apps   push images            <- any workflow in the apps repo
#   tf-plan   read-only plan on PRs  <- any workflow in the infra repo
#   tf-apply  change infrastructure  <- ONLY the infra repo's main branch
# -----------------------------------------------------------------------------

locals {
  infra_repo = "${var.github_owner}/${var.infra_repo}"
  apps_repo  = "${var.github_owner}/${var.apps_repo}"
  pool_path  = google_iam_workload_identity_pool.github.name # projects/<num>/locations/global/workloadIdentityPools/<id>
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub Actions workflows"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_125:Trust is restricted by owner+repository in attribute_condition and by repo/branch-scoped principalSet bindings per SA
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    # Combined attribute so a binding can require repo AND branch at once.
    "attribute.repo_ref" = "assertion.repository + '@' + assertion.ref"
  }

  # Hard gate: tokens from any other owner/repo are rejected before IAM is even evaluated.
  attribute_condition = "assertion.repository_owner == '${var.github_owner}' && assertion.repository in ['${local.infra_repo}', '${local.apps_repo}']"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------------------------------------------------------------------------
# Service accounts
# ---------------------------------------------------------------------------
resource "google_service_account" "ci_apps" {
  project      = var.project_id
  account_id   = "gh-ci-apps"
  display_name = "GitHub Actions - app image builds"
}

resource "google_service_account" "tf_plan" {
  project      = var.project_id
  account_id   = "gh-tf-plan"
  display_name = "GitHub Actions - terraform plan (read-only)"
}

resource "google_service_account" "tf_apply" {
  project      = var.project_id
  account_id   = "gh-tf-apply"
  display_name = "GitHub Actions - terraform apply (main only)"
}

# ---------------------------------------------------------------------------
# Who may impersonate which SA
# ---------------------------------------------------------------------------
resource "google_service_account_iam_member" "ci_apps_wif" {
  service_account_id = google_service_account.ci_apps.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.repository/${local.apps_repo}"
}

resource "google_service_account_iam_member" "tf_plan_wif" {
  service_account_id = google_service_account.tf_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.repository/${local.infra_repo}"
}

resource "google_service_account_iam_member" "tf_apply_wif" {
  service_account_id = google_service_account.tf_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.repo_ref/${local.infra_repo}@refs/heads/${var.main_branch}"
}

# ---------------------------------------------------------------------------
# What each SA may do
# (ci-apps gets artifactregistry.writer on the repository itself, in envs/dev)
# ---------------------------------------------------------------------------
resource "google_project_iam_member" "tf_plan" {
  # Read-only, per service - no basic roles/viewer.
  for_each = toset([
    "roles/browser",
    "roles/container.viewer",
    "roles/compute.networkViewer",
    "roles/artifactregistry.reader",
    "roles/secretmanager.viewer", # metadata only, cannot read secret values
    "roles/iam.serviceAccountViewer",
    "roles/iam.securityReviewer", # read IAM policies during refresh
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tf_plan.email}"
}

# Scoped admin roles instead of roles/owner or roles/editor.
# Note: projectIamAdmin is still powerful (can grant roles) - acceptable for a
# single-project setup, in a company you'd add IAM Conditions or a separate
# IAM pipeline.
resource "google_project_iam_member" "tf_apply" {
  #checkov:skip=CKV_GCP_49:The apply SA must create/manage service accounts; it is only usable from the main branch
  # actAs on the node SA is granted on that single SA (modules/gke), not here.
  for_each = toset([
    "roles/browser",
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin", # firewall rules
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tf_apply.email}"
}

# Both Terraform SAs need the state bucket (read state, write lock file).
resource "google_storage_bucket_iam_member" "state" {
  for_each = {
    plan  = google_service_account.tf_plan.email
    apply = google_service_account.tf_apply.email
  }

  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}
