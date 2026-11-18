terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
  }

  backend "gcs" {
    bucket = "gke-terraform-ardin01-tfstate"
    prefix = "envs/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    managed-by  = "terraform"
    environment = var.environment
  }
}
