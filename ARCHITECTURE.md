# Architecture Overview

## High level
- External traffic -> Ingress
  - dev: ingress-nginx
  - prod: AWS Load Balancer Controller (ALB)
- Workloads run in Kubernetes
  - dev: kind
  - prod: AWS EKS
- Persistence: Oracle (dev local / prod RDS Oracle)

## Services
### agent-ingest-svc
- Accepts incoming telemetry payloads
- Validates + persists/forwards as needed

### device-state-svc
- Computes/serves aggregated device state
- Reads from its own owned persistence

## Configuration
- Env vars + Kubernetes Secrets
- No static credentials committed
- DB credentials:
  - stored in AWS Secrets Manager (prod)
  - injected into Kubernetes Secret by Terraform (prod)
  - mounted as env vars in pods

## AWS (prod)
- ECR for images
- EKS for cluster
- RDS Oracle for DB
- IRSA for pod-to-AWS permissions (logging/metrics etc.)
- Route53 private hosted zone for internal DNS (e.g., `telemetry.internal`)

## Observability
- Prometheus + Grafana via kube-prometheus-stack
- Services expose metrics at `/actuator/prometheus`
- Optional: OpenTelemetry Collector for OTLP traces
- Logs emitted to stdout (CloudWatch initially; Loki optional later)
