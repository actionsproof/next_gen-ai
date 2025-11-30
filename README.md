# nextgen-ai (clean reset)

Minimal reset after secret history contamination. This commit bootstraps a Go 1.23 service with three endpoints:
- `/healthz` returns 200 OK
- `/version` returns build metadata
- `/run` returns stub deterministic payload

Internal placeholder packages: embeddings, reasoning, optimizer, proofs, memory.

Terraform module under `infra/terraform` deploys a single Cloud Run service.

## Local Run
```sh
go run ./cmd/server
```

## Build with metadata
```sh
go build -ldflags "-X main.Version=v0.1.0 -X main.Commit=$(git rev-parse --short HEAD) -X main.Date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" ./cmd/server
```

## Docker
```sh
docker build -t nextgen-ai:local .
```

## Terraform Example
```sh
cd infra/terraform
terraform init
terraform apply -var project_id=next-gen-ai-479815 -var image="IMAGE" -auto-approve
```
