# Vision & Scope

Goal:
Collect and store endpoint telemetry at scale, expose real-time device status, and surface historical trends.

Out of scope (initially):
- UI dashboards
- Multi-tenant billing
- Cloud vendor services (AWS Lambda, etc.)

Primary users:
- "Device agent": pushes telemetry
- "Operator": queries device status/history

Success criteria:
- Can ingest telemetry from N devices per minute
- Can fetch latest status for any device
- Architecture is observable and deployable via Kubernetes/Helm
