output "repository_id" {
  description = "Repository name."
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_url" {
  description = "Docker push/pull prefix, e.g. europe-west3-docker.pkg.dev/<project>/<repo>."
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
