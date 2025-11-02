# Architecture

## High-level flow (Release 2+)
```mermaid
graph LR
  Device[Device Agent] -->|POST /api/telemetry| Ingest[agent-ingest-svc]
  Ingest -->|publish telemetry.raw| Kafka[(Kafka)]
  Kafka --> Proc[telemetry-processor-svc]
  Proc -->|Redis throttle/dedupe| Redis[(Redis)]
  Proc -->|write latest + history| Oracle[(Oracle DB)]
  Oracle --> State[device-state-svc]
  State -->|GET /api/devices/{id}/status| Operator[Operator / Dashboard]
  State -->|GET /api/devices/{id}/history| Operator

Components

agent-ingest-svc
Accepts telemetry from devices (REST), pushes to Kafka.

telemetry-processor-svc
Consumes raw telemetry, normalizes, throttles via Redis, writes "current" and "timeseries" views.

device-state-svc
REST read API for current status and historical data. Reads from Oracle.

Kafka / Redis / Oracle
Infrastructure services in the cluster.

NGINX Ingress
Acts as API gateway. Routes:

/api/telemetry -> agent-ingest-svc

/api/devices/** -> device-state-svc
