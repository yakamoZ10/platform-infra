variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "zone" {
  description = "Zone for the zonal cluster, e.g. europe-west3-a."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name. Also used as node service account prefix (keep it <= 24 chars)."
  type        = string

  validation {
    condition     = length(var.cluster_name) <= 24
    error_message = "cluster_name must be <= 24 chars (service account IDs are limited to 30)."
  }
}

variable "network_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_id" {
  description = "Node subnet id."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for Pods."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for Services."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API (your home IP as /32)."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0
    error_message = "Provide at least one admin CIDR, otherwise nobody can reach the API server."
  }
}

variable "master_ipv4_cidr_block" {
  description = "Only needed for VPC-peering based private clusters. Leave null for PSC-based (default on new GKE versions)."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"
}

variable "database_encryption_key" {
  description = "KMS crypto key id used for application-layer Secrets encryption."
  type        = string
}

variable "deletion_protection" {
  description = "Protect the cluster from terraform destroy."
  type        = bool
  default     = false
}

variable "maintenance_start_time" {
  description = "Daily maintenance window start (UTC, HH:MM)."
  type        = string
  default     = "02:00"
}

variable "machine_type" {
  description = "Machine type for both node pools."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Boot disk size per node. Kept small for free-trial SSD quota."
  type        = number
  default     = 50
}

variable "system_node_count" {
  description = "Number of on-demand nodes in the system pool."
  type        = number
  default     = 1
}

variable "spot_min_nodes" {
  description = "Minimum Spot nodes."
  type        = number
  default     = 1
}

variable "spot_max_nodes" {
  description = "Maximum Spot nodes."
  type        = number
  default     = 3
}

variable "node_sa_users" {
  description = "IAM members allowed to act as the node SA (e.g. the CI terraform-apply SA)."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels applied to cluster and nodes."
  type        = map(string)
  default     = {}
}
