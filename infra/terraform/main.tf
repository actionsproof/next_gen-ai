terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" { type = string }
variable "region" { type = string default = "us-central1" }
variable "service_name" { type = string default = "nextgen-ai" }

resource "google_cloud_run_service" "svc" {
  name     = var.service_name
  location = var.region
  template {
    spec {
      containers {
        image = var.image
      }
    }
  }
  traffics { percent = 100 latest_revision = true }
}

variable "image" { type = string }

output "service_url" { value = google_cloud_run_service.svc.status[0].url }
