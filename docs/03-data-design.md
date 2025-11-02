# Data & Messaging Design

## Kafka topics

### telemetry.raw
- Produced by: agent-ingest-svc
- Consumed by: telemetry-processor-svc
- Contains raw telemetry from devices.

### telemetry.latest
- Produced by: telemetry-processor-svc
- Consumed by: device-state-svc
- Semantics: "most recent known state for each device" (1/deviceId).
- Compaction-friendly.

### telemetry.timeseries
- Produced by: telemetry-processor-svc
- Consumed by: device-state-svc
- Semantics: append-only history for trending and analysis.

## Oracle tables

### device_status_current
- device_id (PK)
- cpu_pct, mem_pct
- disk_alert
- updated_at

### device_status_history
- device_id
- ts
- cpu_pct
- mem_pct
- process_count
- disk_state
- indexed by (device_id, ts)
