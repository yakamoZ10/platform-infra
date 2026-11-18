variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router, NAT and static IP."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names, e.g. platform-dev."
  type        = string
}

variable "nodes_cidr" {
  description = "Primary range for GKE nodes."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for Pods (each node gets a /24 out of this)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for ClusterIP Services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on the node subnet (costs log ingestion)."
  type        = bool
  default     = false
}
