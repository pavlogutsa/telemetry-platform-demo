# Release Roadmap

## Release 1 – MVP
- agent-ingest-svc → Oracle direct write.
- device-state-svc → Oracle read.
- Helm deployment + Prometheus integration.
- GitHub Actions CI pipeline.
- Documentation published via MkDocs.

## Release 2 – Event Backbone
- Introduce Kafka cluster.
- telemetry-processor-svc consumes `telemetry.raw`.
- agent-ingest-svc produces to Kafka.
- device-state-svc decoupled from writes.

## Release 3 – Redis Throttling & History
- Add Redis distributed cache.
- telemetry-processor-svc deduplicates noisy agents.
- Introduce `telemetry.latest` & `telemetry.timeseries`.
- Historical API `/devices/{id}/history`.

## Release 4 – Schema Registry & Observability
- Apicurio Registry for Avro schemas.
- Debezium CDC from Oracle → Kafka.
- Enhanced Prometheus/Grafana dashboards.
- Helm chart linting & automated tests.

## Release 5 – Authentication & Final Polish
- NGINX ingress with API key enforcement.
- Full metrics & alerting coverage.
- MkDocs site complete with diagrams & changelog.
- Optional OKE deployment pipeline.

---

## Future Ideas
- OIDC / JWT-based auth.
- GraphQL read API.
- Multi-tenant support.
- Integration with ClickHouse or Elastic for analytics.
- Synthetic load generator for performance testing.
