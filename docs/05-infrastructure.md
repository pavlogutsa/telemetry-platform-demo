# Infrastructure

## Kubernetes

- All services are deployed into the same namespace.
- Each service has its own Helm chart.
- Oracle XE, Redis, Kafka, and Apicurio (later) also run in the cluster.

## Ingress

We run NGINX Ingress Controller.
We configure one or two Ingress resources:

- `/api/telemetry` -> `agent-ingest-svc`
- `/api/devices/**` -> `device-state-svc`

By Release 5 we enforce API keys at the Ingress layer.

## Scaling

- Only agent-ingest-svc is horizontally scaled early (multiple replicas).
- NGINX routes traffic and K8s Services load-balance replicas.
