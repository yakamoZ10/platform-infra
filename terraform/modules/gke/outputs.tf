output "cluster_name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "location" {
  description = "Cluster zone."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Public control-plane endpoint (restricted by authorized networks)."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "workload_pool" {
  description = "Workload Identity pool, <project>.svc.id.goog."
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_service_account_email" {
  description = "Node service account email."
  value       = google_service_account.nodes.email
}
