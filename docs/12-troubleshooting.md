# 🧱 1. Deployment & Setup

| Command / Config | Purpose | What to Look For |
|------------------|----------|------------------|
| `ORACLE_JDBC_URL=jdbc:oracle:thin:@//oracle-db.telemetry.svc.cluster.local:1521/XEPDB1` | Correct JDBC URL (uses `@//` for service name). | Wrong prefix (`@` only) causes `ORA-12514` / `ORA-12505`. |
| `kind create cluster --name telemetry --config kind-config.yaml` | Create local Kind cluster (ports 80/443 open for ingress). | `kind get clusters` → `telemetry`; `kubectl cluster-info` healthy. |
| `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml` | Install NGINX Ingress Controller into Kind. | `kubectl get pods -n ingress-nginx` → `ingress-nginx-controller` 1/1 Running. |
| `./gradlew clean build` | Build Java microservices (`agent-ingest-svc`, `device-state-svc`). | `BUILD SUCCESSFUL`; JARs under `build/libs`. |
| `docker build -t telemetry/<svc>:local services/<svc>` | Build Docker images for each service. | Image appears in `docker images`. |
| `kind load docker-image telemetry/<svc>:local --name telemetry` | Load built image into Kind’s internal registry. | “Image loaded successfully”; visible in `kubectl describe pod`. |
| `kubectl create namespace telemetry` | Create namespace for all resources. | Listed in `kubectl get ns`. |
| `kubectl create secret generic oracle-credentials --from-literal=ORACLE_USER=telemetry --from-literal=ORACLE_PASSWORD=telemetry_pw --from-literal=ORACLE_JDBC_URL=jdbc:oracle:thin:@//oracle-db.telemetry.svc.cluster.local:1521/XEPDB1 -n telemetry` | Store Oracle credentials. | Secret created successfully. |
| `kubectl apply -f oracle-db.yaml` / `oracle.yml` | Deploy Oracle manually. | `oracle-db-0` pod created, Ready 1/1. |
| `helm upgrade --install oracle . -n telemetry` | Install Oracle via Helm chart. | Successful upgrade/install message. |
| `helm upgrade --install telemetry-platform infra/helm/telemetry-platform -n telemetry --create-namespace` | Deploy full stack (Oracle + services + ingress). | `helm ls` → `STATUS: deployed`; pods Ready. |
| `kubectl get pods -n telemetry -w` | Watch rollout live. | Pods go `Pending → Running → Ready`. |
| `kubectl get svc -n telemetry` | List cluster services. | `oracle-db` → `1521/TCP`. |
| `kubectl get ingress -n telemetry` | Verify ingress resource. | Host `telemetry.local`, correct paths. |
| `kubectl get pvc -n telemetry` | Check persistent volumes. | `oracle-data-oracle-db-0` → `Bound`. |
| `kubectl get endpoints -n telemetry oracle-db` | Validate DB service endpoints. | IP:1521 visible; empty = listener down. |
| `kubectl rollout status deployment/<svc> -n telemetry` | Wait for service rollout. | “successfully rolled out”. |
| `kubectl port-forward svc/agent-ingest-svc -n telemetry 8080:8080` | Test app locally. | `curl http://localhost:8080/actuator/health` → `{"status":"UP"}`. |
| `kubectl port-forward svc/oracle-db 1521:1521 -n telemetry` | Test Oracle locally. | Connect via `jdbc:oracle:thin:@//localhost:1521/XEPDB1`. |
| `helm list -n telemetry` | List Helm releases. | `telemetry-platform` → `deployed`. |
| `kubectl get events -n telemetry --sort-by=.metadata.creationTimestamp` | Review recent namespace events. | Errors, restarts, or CrashLoops. |

---

# 🩺 2. Debugging & Inspection

| Command | Purpose | What to Look For |
|----------|----------|------------------|
| `kubectl logs -f oracle-db-0 -n telemetry` | Stream Oracle startup logs. | `DATABASE IS READY TO USE!` or `Listening on: ... PORT=1521`. |
| `kubectl logs -f agent-ingest-0 -n telemetry` | Watch microservice logs for DB errors. | `ORA-12514`, `ORA-12505`, `ORA-28009`, or “Connection refused”. |
| `kubectl describe pod oracle-db-0 -n telemetry` | Full pod info (events, exit codes, restarts). | `Exit Code 137` (OOMKilled), `57` (Oracle internal). |
| `kubectl logs oracle-db-0 -n telemetry --previous` | View logs from last crash. | Fatal ORA errors before restart. |
| `kubectl exec -it oracle-db-0 -n telemetry -- bash -lc "tail -n 100 /opt/oracle/diag/rdbms/*/*/trace/alert_*.log"` | Inspect Oracle alert log. | ORA-xxxx for memory, file, or startup errors. |
| ``kubectl exec -it -n telemetry deploy/agent-ingest-svc -- printenv | grep ORACLE_`` | View env vars inside container. | All `ORACLE_*` vars set correctly. |
| ``kubectl get secret -n telemetry oracle-credentials -o jsonpath='{.data.ORACLE_JDBC_URL}' | base64 -d`` | Decode JDBC URL from secret. | Correct host, port, and DB name. |
| `kubectl exec -it -n telemetry deploy/agent-ingest-svc -- sh -c "echo > /dev/tcp/oracle-db.telemetry.svc.cluster.local/1521"` | Check Oracle port reachability. | Exit 0 = connection OK. |
| `kubectl run testbox --rm -it --image=busybox -n telemetry -- /bin/sh` → `nc -vz oracle-db.telemetry.svc.cluster.local 1521` | Network test via netcat. | “succeeded/open” = OK. |
| `kubectl exec -it oracle-db-0 -n telemetry -- bash` → `lsnrctl status | grep XEPDB1` | Check listener registration. | Service XEPDB1 listed. |
| `sqlplus sys/$ORACLE_PASSWORD@//localhost/XEPDB1 as sysdba` | Manual Oracle connection. | “Connected to:” output. |
| `kubectl get endpoints -n telemetry <svc>` | Verify service backends. | IP:PORT displayed. |
| `kubectl get pvc -n telemetry` / `kubectl describe pvc <pvc>` | Inspect volume state. | `Bound` = healthy; `Pending` = storage issue. |
| `helm get manifest telemetry-platform -n telemetry` | See rendered Helm YAML. | Verify PVCs, envs, selectors. |
| `helm list -n telemetry` | Confirm Helm release status. | `STATUS: deployed`. |
| `kubectl describe statefulset oracle-db -n telemetry` | Inspect StatefulSet details. | Check `resources:` and `volumeClaimTemplates:`. |
| `kubectl describe statefulset oracle-db -n telemetry | grep -A5 "resources:"` | Review resource limits. | Matches Helm values. |
| `kubectl get pods -n telemetry -w` | Watch pod transitions. | Running → Ready. |
| `kubectl get configmap -n telemetry` | Check Helm-injected configs. | Expected key-value pairs. |
| `kubectl exec -it <pod> -n telemetry -- /bin/bash` | Enter container shell. | Inspect local logs/configs manually. |
| `curl -v http://telemetry.local/api/telemetry` | Full ingress path test. | `200/202` = success; `503` = backend not ready. |

---

# 🧯 3. Troubleshooting & Maintenance

| Command | Purpose | What to Look For / Expected Outcome |
|----------|----------|------------------------------------|
| `kubectl rollout restart deploy/<service> -n telemetry` | Restart deployments after config changes. | Pods recreate → 1/1 Ready. |
| `kubectl delete pod <pod> -n telemetry` | Restart a stuck pod manually. | New pod starts cleanly. |
| `kubectl scale statefulset oracle-db -n telemetry --replicas=0` → `--replicas=1` | Safely restart Oracle. | Pod restarts with new uptime. |
| `kubectl delete statefulset oracle-db -n telemetry` | Remove faulty Oracle instance. | StatefulSet gone, ready to redeploy. |
| `kubectl delete pvc oracle-data-oracle-db-0 -n telemetry` | Reset Oracle data. | PVC deleted → new DB on redeploy. |
| `kubectl patch pvc oracle-data-oracle-db-0 -n telemetry -p '{"metadata":{"finalizers":[]}}' --type=merge` | Remove stuck PVC. | PVC disappears. |
| `kubectl patch svc oracle-db -n telemetry -p '{"spec":{"selector":{"app":"oracle-db"}}}'` | Fix bad Service selector. | `kubectl get endpoints oracle-db` → IP:1521. |
| `kubectl logs -f oracle-db-0 -n telemetry (after redeploy)` | Verify successful DB init. | `######################### DATABASE IS READY TO USE! #########################`. |
| `docker restart` / `kind delete cluster && kind create cluster` | Clean semaphores / reset environment. | Fixes ORA-01081 errors. |
| `kubectl apply -f oracle.yml` (add `/dev/shm` volume) | Increase Oracle shared memory. | Startup memory errors resolved. |
| `kubectl delete namespace telemetry --grace-period=0 --force` | Wipe namespace completely. | Namespace removed. |
| `helm uninstall telemetry-platform -n telemetry` | Remove Helm release. | Helm reports release deleted. |
| `kind delete cluster --name telemetry` | Destroy Kind cluster. | “Deleted clusters: telemetry”. |
| `kubectl run telemetry-smoke-test --rm -i --image=curlimages/curl:8.10.1 -n telemetry --command -- sh -c 'curl -sf http://agent-ingest-svc:8080/actuator/health'` | In-cluster health check. | `{"status":"UP"}`. |
| `curl -v http://localhost:8080/api/telemetry -H "Content-Type: application/json" -d '{...}'` | Manual POST telemetry test. | HTTP 202 success, logs show data ingestion. |

---

# 🧩 4. Quick Symptom Guide

| Symptom | Root Cause | Fix |
|----------|-------------|-----|
| `ORA-12514 / ORA-12505` | Wrong JDBC URL (`@` instead of `@//`). | Use correct format: `jdbc:oracle:thin:@//host:1521/XEPDB1`. |
| `ORA-12541: No listener` | Listener not started or Service has no endpoints. | Restart Oracle; fix Service selector. |
| `ORA-01017: Invalid username/password` | Wrong credentials or missing user. | `CREATE USER telemetry IDENTIFIED BY telemetry_pw;` update secret. |
| `ORA-00942: Table or view does not exist` | Schema missing or migrations not run. | Add Flyway scripts (`V1__create_table.sql`). |
| `ORA-01081` | Stale IPC/semaphore state. | Restart cluster or container. |
| `CrashLoopBackOff` | Repeated startup failures. | Check logs; verify memory, DB, env vars. |
| `Exit Code 137 / OOMKilled` | Insufficient memory. | Increase pod/node memory. |
| `503 Service Temporarily Unavailable` | Ingress with no ready endpoints. | Fix DB connection; pods become Ready. |
| `Connection refused` | Network or port mapping issue. | Verify ingress/port-forward. |
| “`DATABASE IS READY TO USE!`” | Oracle startup complete. | Safe to connect via JDBC. |

---

# ✅ Quick Checklist for Contributors

- **Pods Pending / CrashLoopBackOff** → `kubectl describe pod` + `kubectl logs`.
- **PVC Pending** → Check `WaitForFirstConsumer` or storage class; delete/recreate.
- **Oracle stuck on “Break signaled”** → Delete PVC → restart StatefulSet.
- **No response from services** → `kubectl port-forward` or in-cluster curl.
- **Full redeploy** → Run `kind delete cluster && kind create cluster`.

---

# 🧠 Healthy System Indicators

Oracle logs:
```
######################### DATABASE IS READY TO USE! #########################
```

Microservice health:
```
curl http://telemetry.local/api/telemetry
HTTP 202 / {"status":"UP"}
```

At that point — everything is configured, connected, and operational.
