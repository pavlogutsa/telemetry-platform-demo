# Architecture Decisions (ADR-lite)

## Terragrunt + Terraform
We use Terragrunt for:
- Environment separation (dev vs prod)
- Dependency wiring between stacks
- DRY configuration

## Ingress choice
- dev: ingress-nginx (simple and predictable locally)
- prod: AWS Load Balancer Controller (ALB) for native AWS integration

## Auth for Terraform to EKS
- Do not use kubeconfig in prod automation
- Use exec auth: `aws eks get-token`

## Secrets strategy
- Prod credentials live in AWS Secrets Manager
- Terraform creates Kubernetes Secret for workloads
- Helm charts consume Kubernetes Secret via env vars

## Images strategy
- dev: local build + load into kind
- prod: CI builds and pushes to ECR
- Helm values must reference exact image names (no implicit repos)
