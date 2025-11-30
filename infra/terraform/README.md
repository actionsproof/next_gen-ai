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

## Outputs
- `service_urls`: Map of environment -> URL.
- `primary_service_url`: Convenience prod URL.
- `uptime_check_ids`: Map env -> uptime check config IDs (when enabled).

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
	-var alert_email="alerts@example.com"
```

Then invoke (authenticated example using IAM if unauth disabled):
```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $(terraform output -raw primary_service_url)/run \
	-H "X-API-Key: YOUR_API_KEY"
```
