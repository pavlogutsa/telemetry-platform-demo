# Testing Strategy

## Layers

1. Unit tests
   - JUnit 5
   - AssertJ
   - Mockito for behavior testing

2. Integration tests
   - Testcontainers:
     - Kafka / Redpanda
     - Oracle XE
     - Redis
   - Validates that agent-ingest-svc -> Kafka -> telemetry-processor-svc -> Oracle works

3. End-to-end smoke
   - Run cluster locally (kind / k3d)
   - Apply Helm charts
   - POST /api/telemetry through ingress
   - GET /api/devices/{id}/status
   - Assert data path is correct

## Release gating
Every release must pass end-to-end smoke.
