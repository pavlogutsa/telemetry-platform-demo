# Observability

## 1. Metrics
Each service exposes **Spring Boot Actuator** endpoints:
- `/actuator/health` → readiness/liveness probes.
- `/actuator/prometheus` → Prometheus scrape target.

### Key Metrics
| Service | Metrics Examples |
|----------|-----------------|
| agent-ingest-svc | Request rate, response latency, Kafka produce time |
| telemetry-processor-svc | Kafka consumer lag, processed count, dropped messages |
| device-state-svc | Query latency, cache hits/misses |
| Redis | Memory usage, key eviction count |
| Oracle | Insert latency, connection pool usage |

---

## 2. Prometheus & Grafana
Prometheus scrapes `/actuator/prometheus` from each service.
Grafana visualizes:
- Ingestion rate over time
- DB insert latency
- Kafka consumer lag
- API response times
- Resource utilization per pod

Dashboards live under `helm/observability/grafana/dashboards`.

---

## 3. Logging & Tracing
- Structured JSON logs via Logback.
- Correlation ID (traceId) injected through HTTP headers.
- Future upgrade: OpenTelemetry for distributed tracing.

---

## 4. Alerts
Prometheus rules:
- High CPU / memory on pods
- Kafka consumer lag threshold
- Oracle latency above threshold
- Service down alerts (no /health response)
