variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region (subnet, registry, secrets, KMS)."
  type        = string
}

variable "zone" {
  description = "Zone for the zonal GKE cluster."
  type        = string
}

variable "environment" {
  description = "Environment name, used in resource names."
  type        = string
  default     = "dev"
}

variable "state_bucket" {
  description = "Bucket with the bootstrap state (same bucket as this backend)."
  type        = string
}

variable "admin_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the Kubernetes API. Not committed to Git:
    locally -> local.auto.tfvars, in CI -> TF_VAR_admin_cidrs from the
    GitHub variable TF_ADMIN_CIDRS, e.g. ["203.0.113.7/32"].
  EOT
  type        = list(string)
}

variable "master_ipv4_cidr_block" {
  description = "Only set if GKE insists on a VPC-peering control plane (e.g. 172.16.0.0/28)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protect the cluster from destroy. False here for the rebuild test."
  type        = bool
  default     = false
}

variable "machine_type" {
  description = "Machine type for both node pools."
  type        = string
  default     = "e2-standard-2"
}

variable "system_node_count" {
  description = "On-demand system nodes."
  type        = number
  default     = 1
}

variable "spot_min_nodes" {
  description = "Minimum Spot nodes."
  type        = number
  default     = 1
}

variable "spot_max_nodes" {
  description = "Maximum Spot nodes (1 system + 3 spot x 2 vCPU = 8 vCPU free-trial cap)."
  type        = number
  default     = 3
}

variable "enable_flow_logs" {
  description = "VPC flow logs on the node subnet."
  type        = bool
  default     = false
}
