#GCP provider
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
    project = var.gcp_project
    region = var.gcp_region
}