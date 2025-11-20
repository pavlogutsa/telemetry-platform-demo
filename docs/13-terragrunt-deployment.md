# Local Development Guide: Running Telemetry Platform on Kind

This guide explains how a new developer can deploy the Telemetry Platform locally using:

- **Kind** (Kubernetes-in-Docker)
- **Terragrunt**
- **Helm**
- **Local Docker images**

By the end you will have a full local environment running:

- Oracle XE
- agent-ingest service
- device-state service
- ingress-nginx
- the telemetry gateway at: `http://telemetry.internal/telemetry`

## Prerequisites

Install the following tools:

| Tool | Version | Notes |
|------|---------|-------|
| Docker Desktop | latest | Linux containers required |
| Kind | ≥ 0.20 | kind cluster runner |
| Kubectl | ≥ 1.25 | Kubernetes CLI |
| Terraform | ≥ 1.5 | indirectly used via Terragrunt |
| Terragrunt | ≥ 0.93 | runs Terraform modules |
| Helm | ≥ 3.x | chart installer |
| Gradle | included via wrapper | build services |

## 1. Build and Load Local Images

First, build the services and load their Docker images into the Kind cluster.

### 1.1 Build Java services

From project root:

```bash
./gradlew :agent-ingest-svc:build :device-state-svc:build
```

### 1.2 Build Docker images

```bash
docker build -t telemetry/agent-ingest-svc:local agent-ingest-svc
docker build -t telemetry/device-state-svc:local device-state-svc
```

> **Note:** These tags must match what the Helm chart expects.

### 1.3 Load images into Kind (after cluster exists)

Once the Kind cluster is created (next section), run:

```bash
kind load docker-image telemetry/agent-ingest-svc:local --name telemetry
kind load docker-image telemetry/device-state-svc:local --name telemetry
```

## 2. 🚢 Deploy the Local Kind Environment Using Terragrunt

All infrastructure components are managed through `infra/live/dev`.

The environment consists of:

- Kind cluster (with ingress host port mappings)
- Ingress-nginx (Kind provider variant)
- Telemetry Platform Helm chart

We apply each unit explicitly.

### 2.1 Create the Kind Cluster

```bash
cd infra/live/dev/platform/kind-cluster
terragrunt apply
```

This:

- Creates the Kind cluster `telemetry`
- Adds the `ingress-ready=true` label
- Maps host ports 80 → 80 and 443 → 443

**Verify:**

```bash
kind get clusters
kubectl get nodes
kubectl config get-contexts | grep kind-telemetry
```

### 2.2 Deploy ingress-nginx

```bash
cd ../ingress-nginx
terragrunt apply
```

**Verify:**

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass
```

### 2.3 Deploy the telemetry platform Helm release

```bash
cd ../telemetry-platform
terragrunt apply
```

This installs:

- Oracle DB
- agent-ingest-svc
- device-state-svc
- Ingress with host: `telemetry.internal`

## 3. 🔍 Verification Checklist

### 3.1 Namespace exists

```bash
kubectl get ns
```

**Expected:** `telemetry` and `ingress-nginx`

### 3.2 Pods are running

```bash
kubectl get pods -n telemetry
```

**Expected:**

```
agent-ingest-svc-xxxxx     Running
agent-ingest-svc-yyyyy     Running
device-state-svc-zzzzz     Running
oracle-db-0                Running
```

### 3.3 Ingress is configured

```bash
kubectl get ingress -n telemetry
```

**Expected:**

```
telemetry-gateway   telemetry.internal   80
```

### 3.4 Add host entry (only once)

Edit `/etc/hosts`:

```bash
echo "127.0.0.1 telemetry.internal" | sudo tee -a /etc/hosts
```

### 3.5 End-to-end test

```bash
curl -v http://telemetry.internal/telemetry \
  -H "Content-Type: application/json" \
  -d '{
        "deviceId": "local-test",
        "cpu": 0.5,
        "mem": 0.2,
        "diskAlert": false,
        "timestamp": "2025-11-02T18:22:00Z",
        "processes": []
      }'
```

**Expected:**

```
HTTP/1.1 202 Accepted
```

## 4. Troubleshooting

### ImagePullBackOff / ErrImagePull

**Cause:** images were not loaded into Kind.

**Fix:**

```bash
kind load docker-image telemetry/agent-ingest-svc:local --name telemetry
kind load docker-image telemetry/device-state-svc:local --name telemetry
kubectl rollout restart deployment/agent-ingest-svc -n telemetry
kubectl rollout restart deployment/device-state-svc -n telemetry
```

### curl: Connection refused for telemetry.internal

**Check:**

1. Is ingress-nginx running?

   ```bash
   kubectl get pods -n ingress-nginx
   ```

2. Does `/etc/hosts` contain:

   ```
   127.0.0.1 telemetry.internal
   ```

3. Is Kind mapping hostPort 80 → container?

   ```bash
   docker inspect telemetry-control-plane | grep '"80/tcp"'
   ```

### terraform/terragrunt error: context "kind-telemetry" does not exist

**Cause:** You deleted the cluster but ran `terragrunt plan` before recreating it.

**Fix:** Recreate cluster first:

```bash
cd infra/live/dev/platform/kind-cluster
terragrunt apply
```

### Helm release stuck on Still creating...

Usually caused by image pull failures.

**Check:**

```bash
kubectl get pods -n telemetry
```

If any pod is not Running, fix the pod issue (image, env, container port), then rerun:

```bash
terragrunt apply
```

### Ingress controller Pending

**Cause:** missing node label `ingress-ready=true`.

**Fix:**

```bash
kubectl label node telemetry-control-plane ingress-ready=true --overwrite
```

### Unable to resolve telemetry.internal

**Check DNS/hosts:**

```bash
dig telemetry.internal
```

If empty:

```bash
echo "127.0.0.1 telemetry.internal" | sudo tee -a /etc/hosts
```

## 5. Appendix — All Commands Used in This Guide

Below is every command referenced throughout this onboarding process, grouped by purpose.

### Kind Cluster Management

```bash
kind get clusters
kind delete cluster --name telemetry
kind create cluster --config kind-config.yaml --name telemetry
```

### Terragrunt Deployment

**Create cluster:**

```bash
cd infra/live/dev/platform/kind-cluster
terragrunt apply
```

**Install ingress-nginx:**

```bash
cd ../ingress-nginx
terragrunt apply
```

**Install telemetry platform:**

```bash
cd ../telemetry-platform
terragrunt apply
```

**Run full stack plan (safe):**

```bash
cd infra/live/dev
terragrunt run --all plan
```

> **Note:** Do not run `terragrunt run --all apply` unless the whole environment is idempotent.

### Docker Image Build + Load

```bash
./gradlew :agent-ingest-svc:build :device-state-svc:build

docker build -t telemetry/agent-ingest-svc:local agent-ingest-svc
docker build -t telemetry/device-state-svc:local device-state-svc

kind load docker-image telemetry/agent-ingest-svc:local --name telemetry
kind load docker-image telemetry/device-state-svc:local --name telemetry
```

### Kubernetes Debugging

**Pods:**

```bash
kubectl get pods -n telemetry
kubectl describe pod <pod> -n telemetry
kubectl logs <pod> -n telemetry --all-containers=true
```

**Services, deployments, events:**

```bash
kubectl get all -n telemetry
kubectl get events -n telemetry --sort-by=.lastTimestamp
kubectl get ingress -n telemetry
```

**Rollout restart:**

```bash
kubectl rollout restart deployment/<name> -n telemetry
```

### Ingress + DNS

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass
kubectl describe ingress telemetry-gateway -n telemetry
```

**Add host entry:**

```bash
echo "127.0.0.1 telemetry.internal" | sudo tee -a /etc/hosts
```

### API Testing

```bash
curl -v http://telemetry.internal/telemetry \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```
