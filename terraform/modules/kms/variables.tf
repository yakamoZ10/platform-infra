variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Key ring location (must equal the GKE cluster region)."
  type        = string
}

variable "key_ring_name" {
  description = "Key ring name. Cannot be reused after creation, choose carefully."
  type        = string
  default     = "gke"
}

variable "key_name" {
  description = "Crypto key name."
  type        = string
  default     = "gke-secrets"
}

variable "labels" {
  description = "Labels for the key."
  type        = map(string)
  default     = {}
}
