output "network_id" {
  description = "VPC self link / id."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC name."
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "Node subnet id."
  value       = google_compute_subnetwork.nodes.id
}

output "subnet_name" {
  description = "Node subnet name."
  value       = google_compute_subnetwork.nodes.name
}

output "pods_range_name" {
  description = "Name of the secondary range used for Pods."
  value       = one([for r in google_compute_subnetwork.nodes.secondary_ip_range : r.range_name if r.range_name == "pods"])
}

output "services_range_name" {
  description = "Name of the secondary range used for Services."
  value       = one([for r in google_compute_subnetwork.nodes.secondary_ip_range : r.range_name if r.range_name == "services"])
}

output "ingress_ip" {
  description = "Reserved external IP for the APISIX LoadBalancer."
  value       = google_compute_address.ingress.address
}
