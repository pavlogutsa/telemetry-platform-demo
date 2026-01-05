# Helm Charts

## Rules
- One chart per service
- No `latest` tags
- Images must be specified with full names and tags

## Dev (kind)
- Images are built locally and loaded into kind
- Chart values must match the exact loaded image name
  - Example: `telemetry/agent-ingest-svc:local` (not `agent-ingest-svc:local`)
- `imagePullPolicy: IfNotPresent` is typical

## Prod (EKS)
- Images are pulled from ECR
- `imagePullPolicy: Always` is typical
- Secrets are injected via Kubernetes Secrets created by Terraform (from AWS Secrets Manager)
