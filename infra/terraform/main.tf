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
variable "custom_domain" {
  description = "Optional custom domain mapped to primary environment service (e.g. api.example.com)"
  type        = string
  default     = ""
}
variable "dns_create_zone" {
  description = "If true, create a managed DNS zone for the domain root"
  type        = bool
  default     = false
}
variable "dns_zone_domain" {
  description = "Base DNS domain for zone (e.g. example.com)"
  type        = string
  default     = ""
}
variable "dns_zone_name" {
  description = "Name for managed zone (Terraform identifier)"
  type        = string
  default     = "nextgen-ai-zone"
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

# Optional managed DNS zone (authoritative). Only creates if requested.
resource "google_dns_managed_zone" "primary" {
  count       = var.dns_create_zone && var.dns_zone_domain != "" ? 1 : 0
  name        = var.dns_zone_name
  dns_name    = "${var.dns_zone_domain}." # must end with dot
  description = "Managed zone for ${var.dns_zone_domain}"
}

# Custom domain mapping to prod (or first env) service.
resource "google_cloud_run_domain_mapping" "custom" {
  count    = var.custom_domain != "" ? 1 : 0
  name     = var.custom_domain
  location = var.region
  metadata {
    namespace = var.project_id
  }
  spec {
    route_name = google_cloud_run_service.svc["prod"].name
  }
  depends_on = [google_cloud_run_service.svc]
}

# DNS record (CNAME) pointing custom subdomain to Cloud Run domain target if zone created.
# Cloud Run domain mapping returns resource status with records needed; simplest assumption uses CNAME to ghs.googlehosted.com
resource "google_dns_record_set" "custom_cname" {
  count      = var.custom_domain != "" && var.dns_create_zone && var.dns_zone_domain != "" ? 1 : 0
  name       = "${var.custom_domain}." # FQDN must end with dot
  type       = "CNAME"
  ttl        = 300
  managed_zone = google_dns_managed_zone.primary[0].name
  rrdatas    = ["ghs.googlehosted.com."]
  depends_on = [google_cloud_run_domain_mapping.custom]
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
output "custom_domain" {
  value       = var.custom_domain
  description = "Configured custom domain (if any)"
}
output "dns_zone_name" {
  value       = var.dns_create_zone ? google_dns_managed_zone.primary[0].name : null
  description = "Managed DNS zone name (if created)"
}
