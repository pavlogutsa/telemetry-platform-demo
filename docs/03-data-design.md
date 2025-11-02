# Data & Messaging Design

## 1. Data Flow Overview
Telemetry data travels through multiple transformation layers:

| Stage | Producer | Consumer | Medium | Description |
|-------|-----------|-----------|----------|--------------|
| Raw Telemetry | Device Agent | agent-ingest-svc | REST → Kafka | Device sends JSON payload |
| Normalized | agent-ingest-svc | telemetry-processor-svc | Kafka topic `telemetry.raw` | Standardized structure |
| Latest State | telemetry-processor-svc | device-state-svc | Kafka topic `telemetry.latest` | Most recent record per device |
| Time Series | telemetry-processor-svc | device-state-svc | Kafka topic `telemetry.timeseries` | Append-only history |

---

## 2. Kafka Topics

### `telemetry.raw`
- Unvalidated JSON or Avro messages received from devices.
- Schema defined in Apicurio (added in Release 4).
- Keyed by `deviceId`.

### `telemetry.latest`
- Compact-topic view (1 message per key).
- Used for quick “current status” queries.

### `telemetry.timeseries`
- Append-only, chronological stream.
- Supports trend analysis and visual dashboards.

---

## 3. Oracle Database Schema

### `device_status_current`
| Column | Type | Description |
|--------|------|-------------|
| device_id | VARCHAR2 | Primary key |
| cpu_pct | NUMBER | CPU usage |
| mem_pct | NUMBER | Memory usage |
| disk_alert | BOOLEAN | Disk health flag |
| updated_at | TIMESTAMP | Last updated |

### `device_status_history`
| Column | Type | Description |
|--------|------|-------------|
| device_id | VARCHAR2 | Device reference |
| ts | TIMESTAMP | Timestamp |
| cpu_pct | NUMBER | CPU usage |
| mem_pct | NUMBER | Memory usage |
| process_count | NUMBER | Count of running processes |
| disk_state | VARCHAR2 | OK / ALERT |
| PRIMARY INDEX | (device_id, ts) |

---

## 4. Redis Usage
- **Throttling:** Prevent high-frequency spam from devices.  
- **Deduplication:** Discard identical telemetry bursts within a short time window.  
- **Read Cache (future):** Cache recent device states to reduce DB reads.

---

## 5. Schema Registry (Release 4)
Apicurio Registry defines Avro schemas for `telemetry.*` topics to ensure producer/consumer compatibility.

---

## 6. Debezium (Release 4+)
Optional Oracle → Kafka change data capture for re-emitting DB updates downstream, enabling analytics pipelines.
