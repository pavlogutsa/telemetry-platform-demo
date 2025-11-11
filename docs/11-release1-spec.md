# Telemetry Platform – Release 1 Implementation Spec (Code & Kubernetes)

This document defines all source code, configuration, and deployment files required for **Release 1** of the Telemetry Platform project.

---

## 1. Goal

- Devices send telemetry via HTTP.
- `agent-ingest-svc` receives telemetry and writes the **latest device state** into Oracle DB.
- `device-state-svc` exposes a REST API to read that latest device state.
- Both services run in a local Kubernetes cluster.
- NGINX Ingress exposes:
  - `POST /api/telemetry` → `agent-ingest-svc`
  - `GET /api/devices/{deviceId}/status` → `device-state-svc`
- `/actuator/health` and `/actuator/prometheus` are enabled for both services.

No Kafka, no Redis yet.

---

## 2. Repository Layout

Ensure the following structure under repo root `telemetry-platform-demo/`:

```text
telemetry-platform-demo/
  agent-ingest-svc/
  device-state-svc/
  docs/
    11-release1-spec.md
  helm/
    telemetry-platform/
  kind-config.yaml
  README.md
  build.gradle
  settings.gradle
```

## 3. Technology Stack

- Java 21
- Spring Boot 3.3.5
- Gradle (Groovy DSL, multi-module project)
- Oracle XE
- Spring Web + JDBC + Actuator
- Docker images
- Kubernetes manifests (YAML)
- NGINX Ingress Controller

## 4. Database Design (Oracle)

### 4.1. Schema / User

Assumptions (created manually outside of this spec):

- Oracle XE running with PDB/service name XEPDB1
- DB user: telemetry
- Password: telemetry_pw
- JDBC URL (inside cluster):

```
jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1
```

### 4.2. Table Definition

The table used in Release 1 to store latest device status:

```sql
CREATE TABLE telemetry.device_status_current (
    device_id   VARCHAR2(128) PRIMARY KEY,
    cpu_pct     NUMBER(5,2),
    mem_pct     NUMBER(5,2),
    disk_alert  CHAR(1),
    updated_at  TIMESTAMP
);
```

**Semantics:**

- One row per device_id
- cpu_pct, mem_pct = current CPU/memory usage
- disk_alert = 'Y' if some disk alert is active, 'N' otherwise
- updated_at = last update time (DB time)

## 5. Shared Spring Configuration (Both Services)

Both agent-ingest-svc and device-state-svc must:

- Use Spring Boot 3 + Java 21
- Use Spring JDBC Template
- Read DB connection from environment variables:
  - ORACLE_JDBC_URL
  - ORACLE_USER
  - ORACLE_PASSWORD
- Expose:
  - `/actuator/health`
  - `/actuator/prometheus`

### 5.1. Shared Gradle Build Configuration

The project uses a multi-module Gradle structure with Groovy DSL (`build.gradle`). Plugin versions are managed at the root level.

**Root `build.gradle`:**

```groovy
plugins {
    id 'org.springframework.boot' version '3.3.5' apply false
    id 'io.spring.dependency-management' version '1.1.5' apply false
    id 'java'
}

allprojects {
    group = 'com.telemetry'
    version = '0.0.1-SNAPSHOT'

    repositories {
        mavenCentral()
    }
}

subprojects {
    apply plugin: 'java'

    java {
        sourceCompatibility = JavaVersion.VERSION_21
    }

    tasks.withType(Test).configureEach {
        useJUnitPlatform()
    }
}
```

**Service-level `build.gradle` (e.g., `agent-ingest-svc/build.gradle`):**

```groovy
plugins {
    id("org.springframework.boot")
    id("io.spring.dependency-management")
    id("java")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    implementation("com.oracle.database.jdbc:ojdbc11:23.4.0.24.05")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.assertj:assertj-core:3.26.0")
    testImplementation("org.mockito:mockito-core:5.12.0")
}
```

### 5.2. Shared application.yaml Template

Each service has `src/main/resources/application.yaml`:

```yaml
server:
  port: 8080

spring:
  datasource:
    url: ${ORACLE_JDBC_URL}
    username: ${ORACLE_USER}
    password: ${ORACLE_PASSWORD}
    driver-class-name: oracle.jdbc.OracleDriver

management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  endpoint:
    prometheus:
      enabled: true
```

**Note:**
- Services may use different ports (e.g., agent-ingest-svc: 8080, device-state-svc: 8081) for local development. In Kubernetes, services run in separate pods and can use the same port.
- Kafka configuration may be present in `application.yaml` but is not used in Release 1.

## 6. Service 1 – agent-ingest-svc

### 6.1. Purpose

- Receive telemetry data from devices via HTTP (JSON).
- Persist latest telemetry snapshot per device into telemetry.device_status_current.
- Overwrite existing row for that device_id (upsert semantics).
- HTTP endpoint inside the service: `POST /telemetry`.
- Externally exposed via Ingress as `POST /api/telemetry`.

### 6.2. Project Structure

Under `agent-ingest-svc/`:

```text
agent-ingest-svc/
  build.gradle
  src/
    main/
      java/
        com/telemetry/agent/ingest/
          AgentIngestApplication.java
          api/TelemetryController.java
          api/TelemetryRequest.java
          repo/DeviceStatusRepository.java
      resources/
        application.yaml
```

### 6.3. Main Application Class

`src/main/java/com/telemetry/agent/ingest/AgentIngestApplication.java`:

```java
package com.telemetry.agent.ingest;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AgentIngestApplication {
    public static void main(String[] args) {
        SpringApplication.run(AgentIngestApplication.class, args);
    }
}
```

### 6.4. DTO – TelemetryRequest

`src/main/java/com/telemetry/agent/ingest/api/TelemetryRequest.java`:

```java
package com.telemetry.agent.ingest.api;

import java.time.Instant;
import java.util.List;

public record TelemetryRequest(
        String deviceId,
        double cpu,
        double mem,
        Boolean diskAlert,
        Instant timestamp,
        List<ProcessSample> processes
) {
    public record ProcessSample(
            String name,
            double cpu,
            double mem
    ) {}
}
```

**Requirements:**

- JSON body from clients maps to this record.
- diskAlert may be null (default treat as false).

### 6.5. Repository – DeviceStatusRepository

`src/main/java/com/telemetry/agent/ingest/repo/DeviceStatusRepository.java`:

```java
package com.telemetry.agent.ingest.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;

@Repository
public class DeviceStatusRepository {

    private final JdbcTemplate jdbc;

    public DeviceStatusRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void upsertStatus(String deviceId,
                             double cpuPct,
                             double memPct,
                             boolean diskAlert,
                             Instant timestamp) {

        int updated = jdbc.update("""
            UPDATE telemetry.device_status_current
               SET cpu_pct = ?, mem_pct = ?, disk_alert = ?, updated_at = SYSTIMESTAMP
             WHERE device_id = ?
        """, cpuPct, memPct, diskAlert ? "Y" : "N", deviceId);

        if (updated == 0) {
            jdbc.update("""
                INSERT INTO telemetry.device_status_current
                    (device_id, cpu_pct, mem_pct, disk_alert, updated_at)
                VALUES (?, ?, ?, ?, SYSTIMESTAMP)
            """, deviceId, cpuPct, memPct, diskAlert ? "Y" : "N");
        }
    }
}
```

### 6.6. Controller – TelemetryController

`src/main/java/com/telemetry/agent/ingest/api/TelemetryController.java`:

```java
package com.telemetry.agent.ingest.api;

import com.telemetry.agent.ingest.repo.DeviceStatusRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/telemetry")
public class TelemetryController {

    private final DeviceStatusRepository repo;

    public TelemetryController(DeviceStatusRepository repo) {
        this.repo = repo;
    }

    @PostMapping
    public ResponseEntity<Void> postTelemetry(@RequestBody TelemetryRequest body) {
        if (body.deviceId() == null || body.deviceId().isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        repo.upsertStatus(
                body.deviceId(),
                body.cpu(),
                body.mem(),
                body.diskAlert() != null && body.diskAlert(),
                body.timestamp()
        );

        return ResponseEntity.accepted().build();
    }
}
```

**Behavior:**

- If deviceId is missing or blank → HTTP 400.
- Otherwise:
  - Upsert row in device_status_current.
  - Return HTTP 202 Accepted.

### 6.7. Integration Tests

- Location: `agent-ingest-svc/src/test/java/com/telemetry/agent/ingest/api/TelemetryControllerIntegrationTest.java`
- `postTelemetry_insertsOrUpdatesRowInDb` boots the full Spring context (profile `test`), posts JSON to `/telemetry`, and asserts the row is persisted in `telemetry.device_status_current`.
- `postTelemetry_withoutDeviceId_returnsBadRequestAndDoesNotInsert` verifies a malformed request returns HTTP 400 and leaves the table empty.

## 7. Service 2 – device-state-svc

### 7.1. Purpose

- Read the latest device status from telemetry.device_status_current.
- Expose REST endpoint:
  - Internal: `GET /devices/{deviceId}/status`
  - Via Ingress: `GET /api/devices/{deviceId}/status`.

### 7.2. Project Structure

Under `device-state-svc/`:

```text
device-state-svc/
  build.gradle
  src/
    main/
      java/
        com/telemetry/state/
          DeviceStateApplication.java
          controller/DeviceStatusController.java
          repo/DeviceStatusReadRepository.java
      resources/
        application.yaml
```

### 7.3. Main Application Class

`src/main/java/com/telemetry/state/DeviceStateApplication.java`:

```java
package com.telemetry.state;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DeviceStateApplication {
    public static void main(String[] args) {
        SpringApplication.run(DeviceStateApplication.class, args);
    }
}
```

### 7.4. Repository – DeviceStatusReadRepository

`src/main/java/com/telemetry/state/repo/DeviceStatusReadRepository.java`:

```java
package com.telemetry.state.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;

@Repository
public class DeviceStatusReadRepository {

    private final JdbcTemplate jdbc;

    public DeviceStatusReadRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<DeviceStatus> getStatus(String deviceId) {
        return jdbc.query("""
            SELECT device_id, cpu_pct, mem_pct, disk_alert, updated_at
              FROM telemetry.device_status_current
             WHERE device_id = ?
        """, rs -> {
            if (!rs.next()) {
                return Optional.empty();
            }
            return Optional.of(new DeviceStatus(
                    rs.getString("device_id"),
                    rs.getDouble("cpu_pct"),
                    rs.getDouble("mem_pct"),
                    "Y".equals(rs.getString("disk_alert")),
                    rs.getTimestamp("updated_at").toInstant()
            ));
        }, deviceId);
    }

    public record DeviceStatus(
            String deviceId,
            double cpuPct,
            double memPct,
            boolean diskAlert,
            Instant updatedAt
    ) {}
}
```

### 7.5. Controller – DeviceStatusController

`src/main/java/com/telemetry/state/controller/DeviceStatusController.java`:

```java
package com.telemetry.state.controller;

import com.telemetry.state.repo.DeviceStatusReadRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/devices")
public class DeviceStatusController {

    private final DeviceStatusReadRepository repo;

    public DeviceStatusController(DeviceStatusReadRepository repo) {
        this.repo = repo;
    }

    @GetMapping("/{deviceId}/status")
    public ResponseEntity<?> getStatus(@PathVariable String deviceId) {
        return repo.getStatus(deviceId)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
```

**Behavior:**

- If row exists → HTTP 200 + JSON body of DeviceStatus.
- If not → HTTP 404.

### 7.6. Integration Tests

- Location: `device-state-svc/src/test/java/com/telemetry/state/controller/DeviceStatusControllerIntegrationTest.java`
- `getStatus_existingDevice_returnsStatusJson` loads the Spring context, seeds `telemetry.device_status_current`, and asserts `/devices/{deviceId}/status` returns HTTP 200 with the serialized JSON payload.
- `getStatus_unknownDevice_returns404` ensures an empty database results in HTTP 404 when the device is not found.

## 8. Dockerfiles

Both services are packaged into Docker images.

### 8.1. agent-ingest-svc/Dockerfile

```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY build/libs/*.jar app.jar
ENV JAVA_OPTS=""
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 8.2. device-state-svc/Dockerfile

```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY build/libs/*.jar app.jar
ENV JAVA_OPTS=""
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

## 9. Kubernetes Manifests

All manifests target namespace telemetry.

### 9.1. Secret for Oracle Credentials

`k8s/oracle/oracle-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oracle-credentials
  namespace: telemetry
type: Opaque
stringData:
  ORACLE_PASSWORD: telemetry_pw
  ORACLE_USER: telemetry
  ORACLE_JDBC_URL: jdbc:oracle:thin:@oracle-db.telemetry.svc.cluster.local:1521/XEPDB1
```

### 9.2. Oracle StatefulSet & Service

`k8s/oracle/oracle-statefulset.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: oracle-db
  namespace: telemetry
spec:
  ports:
    - name: sql
      port: 1521
      targetPort: 1521
  clusterIP: None
  selector:
    app: oracle-db
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: oracle-db
  namespace: telemetry
spec:
  serviceName: oracle-db
  replicas: 1
  selector:
    matchLabels:
      app: oracle-db
  template:
    metadata:
      labels:
        app: oracle-db
    spec:
      containers:
        - name: oracle
          image: gvenzl/oracle-xe:21-slim
          env:
            - name: ORACLE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: ORACLE_PASSWORD
          ports:
            - containerPort: 1521
              name: sql
          volumeMounts:
            - name: oracle-data
              mountPath: /opt/oracle/oradata
      volumes:
        - name: oracle-data
          emptyDir: {}
```

**Note:** user/schema/table creation is done separately (via sqlplus).

### 9.3. agent-ingest-svc Chart (Deployment & Service)

`helm/telemetry-platform/charts/agent-ingest-svc/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-ingest-svc
  namespace: telemetry
spec:
  replicas: 2
  selector:
    matchLabels:
      app: agent-ingest-svc
  template:
    metadata:
      labels:
        app: agent-ingest-svc
    spec:
      containers:
        - name: agent-ingest-svc
          image: agent-ingest-svc:release1
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: oracle-credentials
          ports:
            - containerPort: 8080
              name: http
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: agent-ingest-svc
  namespace: telemetry
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/actuator/prometheus"
    prometheus.io/port: "8080"
spec:
  selector:
    app: agent-ingest-svc
  ports:
    - port: 8080
          targetPort: 8080
      name: http
```

### 9.4. device-state-svc Chart (Deployment & Service)

`helm/telemetry-platform/charts/device-state-svc/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: device-state-svc
  namespace: telemetry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: device-state-svc
  template:
    metadata:
      labels:
        app: device-state-svc
    spec:
      containers:
        - name: device-state-svc
          image: device-state-svc:release1
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: oracle-credentials
          ports:
            - containerPort: 8081
              name: http
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8081
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: device-state-svc
  namespace: telemetry
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/actuator/prometheus"
    prometheus.io/port: "8080"
spec:
  selector:
    app: device-state-svc
  ports:
    - port: 8080
      targetPort: 8081
      name: http
```

### 9.5. Ingress – NGINX API Gateway Chart

`helm/telemetry-platform/charts/ingress/templates/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: telemetry-gateway
  namespace: telemetry
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  rules:
    - host: telemetry.local
      http:
        paths:
          - path: /api/telemetry/?(.*)
            pathType: Prefix
            backend:
              service:
                name: agent-ingest-svc
                port:
                  number: 8080
          - path: /api/devices/?(.*)
            pathType: Prefix
            backend:
              service:
                name: device-state-svc
                port:
                  number: 8080
```

**Behavior:**

- External `POST /api/telemetry` → agent-ingest-svc `POST /telemetry`
- External `GET /api/devices/{id}/status` → device-state-svc `GET /devices/{id}/status`

### 9.6. Helm Chart Structure

Helm charts are provided under `helm/telemetry-platform` to deploy the entire stack:

- **Root chart (`Chart.yaml`)** aggregates four dependencies: `oracle`, `agent-ingest-svc`, `device-state-svc`, and `ingress`.
- **Global values (`values.yaml`)** provide shared settings:
  - `global.namespace` = `telemetry`
  - `global.oracle` = default Oracle credentials and JDBC URL (overridable per environment)
  - Dependency overrides use the dependency names (`agent-ingest-svc`, `device-state-svc`, `ingress`) to set images, replica counts, ports, and host.
- **Oracle subchart (`charts/oracle`)** provisions:
  - `Secret` (`oracle-credentials`) using global credentials
  - Optional PVC (enabled by default, size 10Gi)
  - StatefulSet `oracle-db` using image `gvenzl/oracle-xe:21-slim`
- **Service subcharts** (`charts/agent-ingest-svc`, `charts/device-state-svc`) create Deployments and Services that mirror the Kubernetes manifests in sections 9.3 and 9.4. Notable defaults:
  - `agent-ingest-svc`: replicas=2, container port 8080
  - `device-state-svc`: replicas=1, container port 8081 (Service still exposed on port 8080, targeting 8081)
- **Ingress subchart (`charts/ingress`)** exposes the API via host `telemetry.local` with the same path routing as section 9.5.
- **Install example**:

  ```bash
  helm upgrade --install telemetry-platform ./helm/telemetry-platform \
    --namespace telemetry \
    --create-namespace
  ```

  Override values (for example, container images) using `-f custom-values.yaml` or `--set dependencyName.image=...`.

## 10. Local Kubernetes Deployment (Sanity Check)

This flow mirrors the contributor quickstart in `README.md`.

1. **Build the services**
   ```bash
   ./gradlew clean build
   ```

2. **Build Docker images**
   ```bash
   docker build -t agent-ingest-svc:release1 ./agent-ingest-svc
   docker build -t device-state-svc:release1 ./device-state-svc
   ```

3. **Create Kind cluster with ingress ports**
   ```bash
   kind create cluster --name telemetry --config kind-config.yaml
   ```

4. **Load images into Kind**
   ```bash
   kind load docker-image agent-ingest-svc:release1 --name telemetry
   kind load docker-image device-state-svc:release1 --name telemetry
   ```

5. **Install NGINX Ingress (if absent)**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   ```

6. **Deploy with Helm**
   ```bash
   helm dependency update helm/telemetry-platform
   helm upgrade --install telemetry-platform ./helm/telemetry-platform \
     --namespace telemetry \
     --create-namespace
   ```

7. **Map ingress host locally**
   ```
   127.0.0.1 telemetry.local
   ```
   Add the entry above to `/etc/hosts`.

8. **Smoke-test the APIs**
   ```bash
   curl -X POST http://telemetry.local/telemetry \
     -H "Content-Type: application/json" \
     -d '{
           "deviceId": "laptop-4421",
           "cpu": 0.82,
           "mem": 0.73,
           "diskAlert": false,
           "timestamp": "2025-11-02T18:22:00Z",
           "processes": []
         }'

   curl http://telemetry.local/devices/laptop-4421/status
   ```

   Expect HTTP 200 with device telemetry JSON.

9. **Automated reset & deployment**
   - Run `./reset.sh` to execute the full workflow automatically. The script deletes and recreates the Kind cluster, rebuilds services, builds and loads Docker images, installs/updates the NGINX ingress controller, deploys the Helm chart, waits for pods, and runs smoke tests from inside the cluster.

## 11. Acceptance Criteria

Release 1 is considered correctly implemented when:

- Both services compile and pass tests.
- Docker images can be built using the provided Dockerfiles.
- Kubernetes manifests apply cleanly in the telemetry namespace.
- Oracle XE is reachable and device_status_current exists.
- A `POST /api/telemetry` followed by `GET /api/devices/{id}/status` works end-to-end.
- `/actuator/health` returns UP for both services.
- `/actuator/prometheus` is exposed and scrapes metrics for future Prometheus usage.

End of specification.

