# Telemetry Platform - Cursor Rules

You are working inside a repo that contains:
- Java 21 + Spring Boot 3 microservices
- Maven builds
- Docker images
- Kubernetes deployments via Helm
- Terraform + Terragrunt for infra (dev=kind, prod=AWS EKS)
- AWS: ECR, EKS, RDS Oracle, Route53 private zone, Secrets Manager, ALB Controller
- Observability: kube-prometheus-stack, optional OpenTelemetry Collector

## Non-negotiable assumptions
- Two environments:
  - dev: local kind cluster, local images loaded into kind, ingress-nginx
  - prod: AWS EKS, images in ECR, AWS Load Balancer Controller (ALB), exec-auth providers
- Do not mix dev and prod wiring.
- Do not introduce new frameworks unless explicitly asked.
- Do not suggest kubeconfig-based auth for prod Terraform providers - use AWS exec auth (`aws eks get-token`).

## Code generation rules (Java)
- Prefer constructor injection (no field injection)
- Prefer immutable DTOs (records where appropriate)
- Keep controllers thin: validate + delegate
- Keep business logic in services
- Keep persistence isolated (repository layer)
- No cross-service coupling (no shared DB schema, no shared internal libs unless already present)

## Helm rules
- One Helm chart per service
- Values are injected by Terragrunt/Terraform
- Images must be referenced by full name (`repo/name:tag`). No implicit repositories.
- No `latest` tags

## Infra rules
- Terragrunt runs inside `.terragrunt-cache` - avoid fragile relative paths
- Prod providers:
  - Kubernetes provider: host + cluster_ca_data + exec auth
  - Helm provider: same nested Kubernetes exec auth
- Secrets:
  - Prefer AWS Secrets Manager -> Kubernetes Secret
  - Avoid plaintext secrets in Helm values and terragrunt inputs

## Response style
- Prefer minimal, reversible edits consistent with existing structure
- When proposing edits, show exact file paths and full blocks to paste
- If something is ambiguous, make the most likely assumption from repo patterns and state it
