variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Repository location."
  type        = string
}

variable "repository_id" {
  description = "Repository name."
  type        = string
}

variable "keep_recent_versions" {
  description = "Number of most recent image versions always kept."
  type        = number
  default     = 10
}

variable "reader_members" {
  description = "IAM members that may pull images (e.g. GKE node SA)."
  type        = list(string)
  default     = []
}

variable "writer_members" {
  description = "IAM members that may push images (e.g. GitHub Actions SA)."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels for the repository."
  type        = map(string)
  default     = {}
}
