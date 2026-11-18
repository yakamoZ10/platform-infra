variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or org that owns the repositories."
  type        = string
}

variable "infra_repo" {
  description = "Infrastructure repository name (this repo)."
  type        = string
}

variable "apps_repo" {
  description = "Application repository name."
  type        = string
}

variable "main_branch" {
  description = "Branch allowed to run terraform apply."
  type        = string
  default     = "main"
}

variable "state_bucket" {
  description = "GCS bucket holding Terraform state."
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID. Deleted pool IDs are blocked for 30 days."
  type        = string
  default     = "github"
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID."
  type        = string
  default     = "github-actions"
}
