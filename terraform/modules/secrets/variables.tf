variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region where secret replicas are stored."
  type        = string
}

variable "secret_ids" {
  description = "Secret names to create (values are seeded outside Terraform)."
  type        = list(string)
}

variable "workload_pool" {
  description = "Workload Identity pool of the cluster (<project>.svc.id.goog)."
  type        = string
}

variable "eso_gsa_name" {
  description = "Account ID of the GSA used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "eso_namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "eso_ksa_name" {
  description = "Kubernetes service account of External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "labels" {
  description = "Labels for the secrets."
  type        = map(string)
  default     = {}
}
