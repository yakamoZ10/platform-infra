# -----------------------------------------------------------------------------
# Secret Manager secrets + identity for External Secrets Operator (ESO).
#
# Terraform creates only the secret *containers* and IAM. Secret *values* are
# added out-of-band (scripts/seed-secrets.sh), so no password ever lands in
# Terraform state or Git.
#
# ESO (installed on Day 7 via Argo CD) runs as KSA external-secrets/external-secrets
# and impersonates the GSA below through Workload Identity.
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "this" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value
  labels    = var.labels

  replication {
    user_managed {
      replicas {
        location = var.region # data residency: keep secrets in the EU region
      }
    }
  }
}

resource "google_service_account" "eso" {
  project      = var.project_id
  account_id   = var.eso_gsa_name
  display_name = "External Secrets Operator"
}

# Least privilege: access to exactly these secrets, not project-wide.
resource "google_secret_manager_secret_iam_member" "eso" {
  for_each = google_secret_manager_secret.this

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.eso.email}"
}

# Workload Identity: KSA <ns>/<ksa> may act as the GSA.
# Referencing var.workload_pool (a cluster output) makes Terraform wait for
# the cluster; the identity namespace only exists after cluster creation.
resource "google_service_account_iam_member" "eso_workload_identity" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_pool}[${var.eso_namespace}/${var.eso_ksa_name}]"
}
