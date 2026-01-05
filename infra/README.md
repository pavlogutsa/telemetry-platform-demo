# Infrastructure (Terraform + Terragrunt)

## Tools
- Terraform >= 1.6
- Terragrunt >= 0.55 (use `terragrunt run --all plan/apply`)

## Structure
- `modules/` - reusable Terraform modules (no env-specific values)
- `live/` - environment wiring only

## Environments
### dev (kind)
- Targets local kind cluster
- Uses local images loaded into kind
- Ingress via ingress-nginx
- Often uses local paths for Helm charts

### prod (AWS)
Typical dependency chain:
- network/vpc
- platform/ecr
- platform/eks
- platform/rds
- platform/ingress-aws-lb
- platform/iam
- network/dns-internal
- platform/observability
- platform/telemetry-platform

## Path hygiene
Terragrunt executes from `.terragrunt-cache` which can break relative paths.
Prefer repo-root relative patterns and `abspath()` / `get_repo_root()` helpers where needed.
