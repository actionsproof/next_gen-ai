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
variable "enable_uptime" {
  description = "Enable Monitoring uptime checks and alert policy"
  type        = bool
  default     = true
}
variable "alert_email" {
  description = "Email for uptime alert notifications (optional)"
  type        = string
  default     = ""
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

# Uptime checks per environment (optional)
resource "google_monitoring_uptime_check_config" "http" {
  for_each    = var.enable_uptime ? google_cloud_run_service.svc : {}
  display_name = "uptime-${each.key}"
  timeout      = "10s"
  period       = "60s"
  http_check {
    path    = "/healthz"
    port    = 443
    use_ssl = true
  }
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(google_cloud_run_service.svc[each.key].status[0].url, "https://", "")
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.enable_uptime && var.alert_email != "" ? 1 : 0
  display_name = "uptime-email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  count       = var.enable_uptime ? 1 : 0
  display_name = "Cloud Run uptime"
  combiner     = "OR"
  conditions {
    display_name = "uptime-failure"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "0s"
      trigger { count = 1 }
    }
  }
  notification_channels = var.alert_email != "" && var.enable_uptime ? [google_monitoring_notification_channel.email[0].name] : []
  depends_on = [google_monitoring_uptime_check_config.http]
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
output "uptime_check_ids" {
  value       = var.enable_uptime ? { for k, v in google_monitoring_uptime_check_config.http : k => v.id } : {}
  description = "Map of environment to uptime check config IDs"
}
