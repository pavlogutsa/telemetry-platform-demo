# Observability

All services expose Spring Boot Actuator metrics on `/actuator/prometheus`.

## Prometheus scrapes

- agent-ingest-svc (ingest rate, request latency)
- telemetry-processor-svc (Kafka lag, dropped telemetry due to throttling)
- device-state-svc (DB write latency, DB error count)

## Grafana dashboards

- Ingest RPS
- Oracle insert latency
- Redis throttle hits/sec
- Time from POST /api/telemetry to visible /status
