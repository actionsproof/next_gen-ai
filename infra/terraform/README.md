# Terraform (multi-env) for nextgen-ai

This configuration deploys one Cloud Run service per environment (default only `prod`).

## Variables
- `project_id` (string): GCP project ID.
- `region` (string): Region (default `us-central1`).
- `service_name` (string): Base service name (default `nextgen-ai`).
- `image` (string): Container image reference (required).
- `environments` (list(string)): Environment names (default `["prod"]`).
- `allow_unauthenticated` (bool): If true, grants public invoker (`allUsers`).
- `api_key` (string): Optional API key injected as env var `API_KEY`.
- `enable_uptime` (bool): Enable uptime checks + alert (default `true`).
- `alert_email` (string): Email for notification channel (optional).
- `custom_domain` (string): Optional domain mapped to prod service (e.g. `api.example.com`).
- `dns_create_zone` (bool): Create managed DNS zone for `dns_zone_domain`.
- `dns_zone_domain` (string): Base domain (e.g. `example.com`).
- `dns_zone_name` (string): Terraform zone resource name (default `nextgen-ai-zone`).

## Outputs
- `service_urls`: Map of environment -> URL.
- `primary_service_url`: Convenience prod URL.
- `uptime_check_ids`: Map env -> uptime check config IDs (when enabled).
- `custom_domain`: The configured custom domain (if any).
- `dns_zone_name`: Managed zone name if created.

## Example
```sh
terraform init
terraform apply \
	-var project_id=next-gen-ai-479815 \
	-var image="us-docker.pkg.dev/next-gen-ai-479815/nextgen-ai/nextgen-ai:abcdef" \
	-var environments='["staging","prod"]' \
	-var allow_unauthenticated=false \
	-var api_key="YOUR_API_KEY" \
	-var enable_uptime=true \
	-var alert_email="alerts@example.com" \
	-var custom_domain="api.example.com" \
	-var dns_create_zone=true \
	-var dns_zone_domain="example.com"
### Domain Mapping Notes
Cloud Run managed domain mapping will verify ownership. When Terraform creates a zone and CNAME (`api.example.com -> ghs.googlehosted.com`), DNS propagation must complete before mapping becomes active. For existing external DNS, skip zone creation and only set `custom_domain` then manually add required records (A/AAAA or CNAME per Google instructions) if different from default.

```

Then invoke (authenticated example using IAM if unauth disabled):
```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $(terraform output -raw primary_service_url)/run \
	-H "X-API-Key: YOUR_API_KEY"
```
