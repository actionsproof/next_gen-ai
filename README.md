# nextgen-ai

Enterprise skeleton (clean history). Go 1.23 service exposes:
- `GET /healthz` health probe
- `GET /version` build metadata (Version, Commit, Date via ldflags)
- `GET /run` deterministic stub; optional API key auth via `X-API-Key` if `API_KEY` env set.

Internal deterministic placeholder packages: `embeddings`, `reasoning`, `optimizer`, `proofs`, `memory`.

## Features
- Multi-environment Cloud Run deploy via Terraform (`environments` variable)
- Optional public access (`allow_unauthenticated=false` => IAM only)
- API key injection through Terraform variable `api_key`
- GitHub Actions: CI (lint, security, tests), Release (multi-platform binaries + checksums), Deploy, Canary traffic split, Infra apply, Load testing (k6)
- k6 performance script for `/run`

## Local Run
```sh
go run ./cmd/server
```

With API key:
```sh
API_KEY=secret go run ./cmd/server
curl -H "X-API-Key: secret" http://localhost:8080/run
```

## Build with Metadata
```sh
go build -ldflags "-X main.Version=v0.1.0 -X main.Commit=$(git rev-parse --short HEAD) -X main.Date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" ./cmd/server
```

## Docker
```sh
docker build -t nextgen-ai:local .
docker run -p 8080:8080 -e API_KEY=secret nextgen-ai:local
```

## Terraform (Multi-Env)
```sh
cd infra/terraform
terraform init
terraform apply \
	-var project_id=next-gen-ai-479815 \
	-var image="us-docker.pkg.dev/next-gen-ai-479815/nextgen-ai/nextgen-ai:SHA" \
	-var environments='["staging","prod"]' \
	-var allow_unauthenticated=false \
	-var api_key="secret"
```
Output: `service_urls` map & `primary_service_url`.

Invoke secured service (unauth disabled):
```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
		 -H "X-API-Key: secret" $(terraform output -raw primary_service_url)/run
```

## CI Overview
- `ci.yml`: lint (golangci-lint), gosec, tests (race), build
- `release.yml`: tag `v*` builds binaries, SHA256SUMS
- `deploy-gcp.yml`: manual dispatch builds & deploys per environment
- `canary-deploy.yml`: splits traffic between revisions
- `infra-apply.yml`: Terraform apply with chosen image tag
- `loadtest.yml`: k6 script against deployed URL

## k6 Example
```sh
docker run --rm -i grafana/k6 run -e BASE_URL="http://localhost:8080" -e API_KEY=secret - < loadtest/script.js
```

## Releasing
Create tag: `git tag v0.1.0 && git push origin v0.1.0`. Artifacts appear under workflow run.

## Packaging (Manual)
See `release.yml` for matrix; replicate locally:
```sh
VERSION=v0.1.0; COMMIT=$(git rev-parse --short HEAD); DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for GOOS in linux windows; do for GOARCH in amd64 arm64; do \
	EXT=""; [ "$GOOS" = windows ] && EXT=".exe"; \
	GOOS=$GOOS GOARCH=$GOARCH go build -trimpath -ldflags "-X main.Version=$VERSION -X main.Commit=$COMMIT -X main.Date=$DATE" -o dist/nextgen-ai_${VERSION}_${GOOS}_${GOARCH}$EXT ./cmd/server; \
done; done
shasum -a 256 dist/* > dist/SHA256SUMS.txt
```

## Security Notes
- API key optional; if unset endpoint is open (subject to Cloud Run auth policy)
- Set `allow_unauthenticated=false` for IAM-only access + identity token curl
- `gosec` runs in CI; extend `.golangci.yml` for stricter rules as needed

## Future Enhancements
- Add managed domain + DNS automation
- Add uptime check + alerting
- Add embedding/LLM real implementations

---
Clean history established; previous secret-containing commits removed.
