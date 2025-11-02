# Release Roadmap

## Release 1 (MVP)
- agent-ingest-svc writes directly to Oracle
- device-state-svc reads Oracle
- Ingress routes /api/telemetry and /api/devices/*
- Basic docs + Helm + Prometheus scrape

## Release 2
- Add Kafka + telemetry-processor-svc
- agent-ingest-svc now produces telemetry.raw to Kafka
- telemetry-processor-svc writes Oracle
- device-state-svc becomes read-only + status API

## Release 3
- Add Redis throttling and timeseries/history tables
- device-state-svc serves status + history

## Release 4
- Add schema registry (Apicurio) + Avro
- Add dashboards (Grafana)
- Add CI/CD with Testcontainers and Helm deploy

## Release 5
- Add authn/authz at ingress (API keys per role)
- Audit headers propagated downstream
