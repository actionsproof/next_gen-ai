output "service_urls" {
	description = "Map of environment to service URL"
	value       = { for k, s in google_cloud_run_service.svc : k => s.status[0].url }
}
output "primary_service_url" {
	value       = try(google_cloud_run_service.svc["prod"].status[0].url, null)
	description = "Convenience output for prod URL if present"
}
