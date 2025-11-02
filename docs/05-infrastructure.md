# Infrastructure

## 1. Local Deployment

All components deploy to a local Kubernetes cluster (Kind, k3d, or Minikube) via Helm charts under `/helm`.

| Component | Chart Path | Purpose |
|------------|-------------|----------|
| agent-ingest-svc | `helm/agent-ingest-svc` | REST ingestion service |
| telemetry-processor-svc | `helm/telemetry-processor-svc` | Kafka consumer / DB writer |
| device-state-svc | `helm/device-state-svc` | REST read service |
| redis | `helm/redis` | Cache & throttling |
| kafka | `helm/kafka` | Event backbone |
| oracle-xe | `helm/oracle` | Primary persistence |
| nginx-ingress | `helm/nginx-ingress` | API gateway |
| prometheus / grafana | `helm/observability` | Metrics stack |
| observability | `helm/observability` | Prometheus + Grafana |

Deploy locally:

```bash
helm dependency update ./helm
helm install telemetry ./helm
kubectl port-forward svc/nginx-ingress-controller 8080:80
```

Access APIs through `http://localhost:8080/api/....`

---

## 2. Containerization

Each service builds as a multi-arch Docker image using Spring Boot 3's buildpacks:

```bash
./gradlew bootBuildImage
```

Images run on both amd64 and arm64 (Apple Silicon).  
Helm values reference these tagged images (e.g., `ghcr.io/pavlogutsa/agent-ingest-svc:latest`).

---

## 3. CI/CD Pipeline

GitHub Actions orchestrates:

- **Build & Test** – Gradle compile, unit, and integration tests.
- **Docker Build & Push** – buildpacks to registry.
- **Helm Lint & Template** – validate charts.
- **MkDocs Build** – docs built & deployed to Pages.
- (Optional) Terraform apply → OKE deployment.

---

## 4. Oracle Cloud (OCI) Deployment

OCI free tier supports running this architecture using:

- Oracle Kubernetes Engine (OKE) for containers.
- Oracle Autonomous DB or containerized XE instance.
- Object Storage for backups.

Terraform modules provision:

- VCN + subnets
- Node pools
- Load balancers
- Helm releases per component

---

## 5. Scaling & Load Balancing

- **agent-ingest-svc** – scales horizontally; ingress load-balances requests.
- **Kafka** – partitioned topics for parallelism.
- **Redis** – cluster mode for throughput.
- **Oracle** – partitioned tables, connection pool tuning.
- **Prometheus + Grafana** – scaled via stateful sets.

---

## 6. Backup & Recovery

- Oracle export via `expdp` container job.
- Kafka topic retention policy: 7–14 days.
- Redis persistence optional (AOF).
- Helm values define storage classes for stateful components.

---

## 7. Future Infrastructure

- CI/CD promotion pipeline (dev → staging → prod).
- Canary deployments via ingress annotations.
- Terraform modules for AWS EKS and GCP GKE equivalents.
