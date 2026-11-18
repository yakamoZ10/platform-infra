output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "GKE cluster zone."
  value       = module.gke.location
}

output "get_credentials_command" {
  description = "Run this to configure kubectl."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${module.gke.location} --project ${var.project_id}"
}

output "artifact_registry_url" {
  description = "Image prefix, e.g. <url>/orders:<git-sha>."
  value       = module.artifact_registry.repository_url
}

output "ingress_ip" {
  description = "Static IP for the APISIX LoadBalancer (Day 4). Hostnames like api.<ip>.nip.io work without a domain."
  value       = module.network.ingress_ip
}

output "node_service_account" {
  description = "GKE node service account."
  value       = module.gke.node_service_account_email
}

output "external_secrets_gsa" {
  description = "Annotate the ESO KSA with iam.gke.io/gcp-service-account=<this> (Day 7)."
  value       = module.secrets.eso_gsa_email
}

output "secret_ids" {
  description = "Secret Manager secrets (seed values with scripts/seed-secrets.sh)."
  value       = module.secrets.secret_ids
}
