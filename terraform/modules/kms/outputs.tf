output "gke_secrets_key_id" {
  description = "Full KMS key id for GKE database encryption."
  value       = google_kms_crypto_key.gke_secrets.id
}
