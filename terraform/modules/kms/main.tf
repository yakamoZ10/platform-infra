# -----------------------------------------------------------------------------
# KMS key for GKE application-layer Secrets encryption (CMEK).
#
# Lives in the bootstrap layer on purpose: KMS key rings and keys can NEVER be
# deleted in GCP. If they were in envs/dev, `terraform destroy` + `apply`
# would fail with "already exists".
# -----------------------------------------------------------------------------

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = var.key_ring_name
  location = var.region # must match the cluster's region
}

resource "google_kms_crypto_key" "gke_secrets" {
  name            = var.key_name
  key_ring        = google_kms_key_ring.this.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days
  labels          = var.labels

  lifecycle {
    prevent_destroy = true
  }
}

# The GKE service agent (Google-managed) must be able to use the key.
resource "google_kms_crypto_key_iam_member" "gke_service_agent" {
  crypto_key_id = google_kms_crypto_key.gke_secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.this.number}@container-engine-robot.iam.gserviceaccount.com"
}
