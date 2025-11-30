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
variable "environments" {
  description = "List of environment names to deploy distinct Cloud Run services"
  type        = list(string)
  default     = ["prod"]
}
variable "allow_unauthenticated" {
  description = "If true, services are public; otherwise IAM secured"
  type        = bool
  default     = true
}

resource "google_cloud_run_service" "svc" {
  for_each = toset(var.environments)
  name     = "${var.service_name}-${each.key}"
  location = var.region
  template {
    spec {
      containers {
        image = var.image
        ports { container_port = 8080 }
        env {
          name  = "API_KEY"
          value = var.api_key
        }
      }
    }
  }
  traffics { percent = 100 latest_revision = true }
}

variable "api_key" {
  description = "Optional API key injected as env var"
  type        = string
  default     = ""
}

data "google_project" "current" {}

resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = var.allow_unauthenticated ? toset(var.environments) : []
  location = var.region
  service  = google_cloud_run_service.svc[each.key].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

variable "image" { type = string }

output "service_urls" {
  description = "Map of environment to service URL"
  value       = { for k, s in google_cloud_run_service.svc : k => s.status[0].url }
}
output "primary_service_url" {
  value = google_cloud_run_service.svc["prod"].status[0].url
  description = "Convenience output for prod URL"
}
