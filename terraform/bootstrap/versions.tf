terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
  }

  # Backend blocks can't use variables. Change the bucket if your project ID differs.
  backend "gcs" {
    bucket = "gke-terraform-ardin01-tfstate"
    prefix = "bootstrap"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    managed-by = "terraform"
    layer      = "bootstrap"
  }
}
