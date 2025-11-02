# Security & Auth

Release 5 introduces:
- Authentication at the ingress using API keys.
- Different keys/roles:
  - ingest role: allowed to POST /api/telemetry
  - read role: allowed to GET /api/devices/**

Ingress enforces:
- Rejects missing/invalid key at the edge (401).
- Injects headers like X-Caller-Role for downstream audit.

Future:
- Swap API keys for JWT/OIDC validation at ingress.
