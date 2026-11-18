variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
}

variable "state_bucket" {
  description = "GCS bucket for Terraform state (created manually with gcloud)."
  type        = string
}

variable "github_owner" {
  description = "Your GitHub username (or org)."
  type        = string

  validation {
    condition     = var.github_owner != "CHANGE_ME" && length(var.github_owner) > 0
    error_message = "Set github_owner in terraform.tfvars to your GitHub username."
  }
}

variable "infra_repo" {
  description = "Name of the infrastructure repository."
  type        = string
  default     = "platform-infra"
}

variable "apps_repo" {
  description = "Name of the application repository."
  type        = string
  default     = "platform-apps"
}
