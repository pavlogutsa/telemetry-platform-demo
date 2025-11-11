#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Telemetry Platform full reset + deploy + smoke test
# ==============================================================================
# This script will:
#   - delete and recreate a kind cluster "telemetry"
#   - build Java services
#   - build Docker images
#   - load images into kind
#   - deploy everything via Helm
#   - wait for pods to be ready
#   - run smoke tests against the services inside the cluster
#
# Requirements:
#   - Docker (Docker Desktop running)
#   - kind
#   - kubectl
#   - helm
#   - JDK & ./gradlew
# ==============================================================================

### Config #####################################################################

KIND_CLUSTER_NAME="telemetry"
NAMESPACE="telemetry"
HELM_RELEASE="telemetry-platform"
HELM_CHART_PATH="helm/telemetry-platform"
KIND_CONFIG="kind-config.yaml"

AGENT_IMAGE="telemetry/agent-ingest-svc:local"
DEVICE_IMAGE="telemetry/device-state-svc:local"

### Helpers ####################################################################

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command '$1' not found in PATH"
  fi
}

### Pre-flight checks ##########################################################

log "Checking required commands"
require_cmd docker
require_cmd kind
require_cmd kubectl
require_cmd helm
require_cmd java

if [ ! -x "./gradlew" ]; then
  fail "./gradlew not found or not executable in repo root"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "$KIND_CONFIG" ]; then
  fail "Kind config file not found at '$KIND_CONFIG'"
fi

if [ ! -d "agent-ingest-svc" ] || [ ! -d "device-state-svc" ]; then
  fail "Service directories not found at repo root. Check repo layout."
fi

### 1. Reset kind cluster ######################################################

if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
  log "Deleting existing kind cluster '$KIND_CLUSTER_NAME'"
  kind delete cluster --name "$KIND_CLUSTER_NAME"
fi

log "Creating kind cluster '$KIND_CLUSTER_NAME' using $KIND_CONFIG"
kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG"

log "kind cluster info"
kubectl cluster-info

### 2. Build Java services #####################################################

log "Building Java services with Gradle"
./gradlew :agent-ingest-svc:build :device-state-svc:build

### 3. Build Docker images #####################################################

log "Building Docker image for agent-ingest-svc: $AGENT_IMAGE"
docker build -t "$AGENT_IMAGE" agent-ingest-svc

log "Building Docker image for device-state-svc: $DEVICE_IMAGE"
docker build -t "$DEVICE_IMAGE" device-state-svc

### 4. Load images into kind ###################################################

log "Loading images into kind cluster '$KIND_CLUSTER_NAME'"
kind load docker-image "$AGENT_IMAGE" --name "$KIND_CLUSTER_NAME"
kind load docker-image "$DEVICE_IMAGE" --name "$KIND_CLUSTER_NAME"

### 5. NGINX ingress controller ###############################################

log "Installing NGINX ingress controller (if not already present)"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

### 6. Helm deploy #############################################################

log "Updating Helm chart dependencies"
helm dependency update "$HELM_CHART_PATH"

log "Deploying Helm release '$HELM_RELEASE' from chart '$HELM_CHART_PATH' into namespace '$NAMESPACE'"

helm upgrade --install "$HELM_RELEASE" "$HELM_CHART_PATH" \
  -n "$NAMESPACE" \
  --create-namespace \
  --wait \
  --timeout 10m

### 7. Wait for pods to be ready ###############################################

log "Waiting for Oracle StatefulSet to be ready"
kubectl rollout status statefulset/oracle-db -n "$NAMESPACE" --timeout=600s

log "Waiting for agent-ingest-svc deployment to be ready"
kubectl rollout status deployment/agent-ingest-svc -n "$NAMESPACE" --timeout=300s

log "Waiting for device-state-svc deployment to be ready"
kubectl rollout status deployment/device-state-svc -n "$NAMESPACE" --timeout=300s

log "Current pods in namespace '$NAMESPACE'"
kubectl get pods -n "$NAMESPACE"

### 8. Smoke tests #############################################################

log "Running smoke tests from inside the cluster (curlimages/curl)"

SMOKE_SCRIPT='
set -e

echo "[smoke] Checking agent-ingest-svc health..."
curl -sf http://agent-ingest-svc:8080/actuator/health
echo
echo "[smoke] agent-ingest-svc health OK"

echo "[smoke] Checking device-state-svc health..."
curl -sf http://device-state-svc:8080/actuator/health
echo
echo "[smoke] device-state-svc health OK"

echo "[smoke] Sending sample telemetry to agent-ingest-svc..."
curl -sf -X POST http://agent-ingest-svc:8080/telemetry \
  -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"smoke-test-device\",\"cpu\":0.5,\"mem\":0.4,\"diskAlert\":false,\"timestamp\":\"2025-11-02T18:22:00Z\",\"processes\":[]}"
echo
echo "[smoke] Telemetry POST returned success"

echo "[smoke] Fetching device status from device-state-svc..."
curl -sf http://device-state-svc:8080/devices/smoke-test-device/status
echo
echo "[smoke] Device status fetch returned success"

echo "[smoke] All smoke tests passed."
'

kubectl run telemetry-smoke-test \
  -n "$NAMESPACE" \
  --restart=Never \
  --rm -i \
  --image=curlimages/curl:8.10.1 \
  --command -- sh -c "$SMOKE_SCRIPT"

### 9. Summary #################################################################

log "All components are up and running, and smoke tests passed 🎉"
echo "You can now port-forward services, for example:"
echo "  kubectl port-forward svc/agent-ingest-svc -n $NAMESPACE 8080:8080"
echo "Then hit: http://localhost:8080/actuator/health"
