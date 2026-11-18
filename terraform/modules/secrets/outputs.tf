output "secret_ids" {
  description = "Created secret names."
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}

output "eso_gsa_email" {
  description = "GSA email to annotate the ESO Kubernetes service account with (iam.gke.io/gcp-service-account)."
  value       = google_service_account.eso.email
}
