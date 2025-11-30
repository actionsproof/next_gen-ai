# Minimal Terraform for nextgen-ai

Variables:
- project_id: GCP project
- region: Deploy region (default us-central1)
- service_name: Cloud Run service name
- image: Container image (required)

Example:
```sh
terraform init
terraform apply -var project_id=next-gen-ai-479815 -var image="us-docker.pkg.dev/next-gen-ai-479815/nextgen-ai/app:latest"
```
