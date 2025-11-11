#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Telemetry Platform full reset + deploy + smoke test
# ==============================================================================
# This script will:
#   - delete and recreate a kind cluster "telemetry"         (default full run)
#   - (optionally) build Java services
#   - (optionally) build Docker images
#   - load images into kind
#   - deploy everything via Helm
#   - wait for pods to be ready
#   - (optionally) run smoke tests against the services inside the cluster
#
# Additional modes:
#   --cluster-only     : just recreate kind cluster, no Helm, no images, no smoke
#   --smoke-only       : just run smoke tests against existing deployment
#   --rebuild-agent    : rebuild/redeploy agent-ingest-svc only (no cluster reset)
#   --rebuild-device   : rebuild/redeploy device-state-svc only (no cluster reset)
#
# Requirements:
#   Full / rebuild:
#     - Docker (Docker Desktop running)
#     - kind
#     - kubectl
#     - helm (for full reset only)
#     - JDK & ./gradlew
#
#   --cluster-only:
#     - kind, kubectl
#
#   --smoke-only:
#     - kubectl
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

usage() {
  cat <<EOF
Usage: $0 [options]

Modes (mutually exclusive in some combinations):
  (no mode flags)     Full reset:
                        - Delete and recreate kind cluster '$KIND_CLUSTER_NAME'
                        - Build both services with Gradle
                        - Build Docker images
                        - Load images into kind
                        - Deploy Helm release '$HELM_RELEASE'
                        - Wait for Oracle and services to be Ready
                        - Run smoke tests (unless --skip-smoke)

  --cluster-only      Cluster reset only:
                        - Delete and recreate kind cluster '$KIND_CLUSTER_NAME'
                        - No Gradle, no Docker, no Helm, no smoke tests

  --smoke-only        Smoke tests only:
                        - Do NOT touch cluster or deployments
                        - Runs in-cluster smoke tests against existing namespace '$NAMESPACE'
                        - Assumes Helm release '$HELM_RELEASE' is already deployed and healthy

  --rebuild-agent     Rebuild and redeploy *only* agent-ingest-svc:
                        - Does NOT delete or recreate kind cluster
                        - Does NOT re-run Helm
                        - Rebuilds / reloads only agent-ingest-svc (unless skip flags used)
                        - Restarts agent-ingest-svc deployment and waits for rollout
                        - Runs smoke tests (unless --skip-smoke)

  --rebuild-device    Rebuild and redeploy *only* device-state-svc:
                        - Same behavior as --rebuild-agent, but for device-state-svc

  You can combine:
    --rebuild-agent and --rebuild-device  (rebuild both on existing cluster)

  You CANNOT combine:
    --cluster-only with --rebuild-* or --smoke-only
    --smoke-only with --rebuild-*

Build / test / image flags:
  --skip-build       Skip Gradle build step:
                       - JARs in build/libs must already exist
                       - In full mode: both services' existing JARs are used for Docker builds
                       - In rebuild mode: only the selected service(s) use existing JARs

  --skip-tests       Skip Gradle tests:
                       - Effective only when --skip-build is NOT used
                       - Equivalent to Gradle -x test for the relevant projects

  --skip-images      Skip Docker image builds:
                       - Assumes Docker images already exist locally with tags:
                           $AGENT_IMAGE
                           $DEVICE_IMAGE
                       - Images are still loaded into kind (kind load docker-image ...)

Runtime / verification flags:
  --skip-smoke       Skip in-cluster smoke tests:
                       - Useful when iterating quickly on deployments
                       - All other steps (build, deploy, rollouts) still run

  -h, --help         Show this help message and exit

Examples:
  Full reset + deploy + smoke tests:
    $0

  Full reset but skip tests during Gradle build:
    $0 --skip-tests

  Reset cluster only (for a clean k8s environment):
    $0 --cluster-only

  Rebuild only agent-ingest-svc after code changes (with tests):
    $0 --rebuild-agent

  Rebuild only agent-ingest-svc, skip tests and smoke tests:
    $0 --rebuild-agent --skip-tests --skip-smoke

  Rebuild only device-state-svc, using existing JAR and image:
    $0 --rebuild-device --skip-build --skip-images

  Run smoke tests against current deployment without touching the cluster:
    $0 --smoke-only
EOF
}

### 0. Smoke test function #####################################################

run_smoke_tests() {
  log "Running smoke tests from inside the cluster (curlimages/curl)"

  # Basic sanity: namespace must exist
  if ! kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
    fail "Namespace '$NAMESPACE' not found. Deploy the platform before running smoke tests."
  fi

  # Optional: show current pods
  log "Pods in namespace '$NAMESPACE' before smoke tests"
  kubectl get pods -n "$NAMESPACE"

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
set +e
HTTP_CODE=$(curl -s -o /tmp/telemetry-response.json -w "%{http_code}" \
  -X POST http://agent-ingest-svc:8080/telemetry \
  -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"smoke-test-device\",\"cpu\":0.5,\"mem\":0.4,\"diskAlert\":false,\"timestamp\":\"2025-11-02T18:22:00Z\",\"processes\":[]}")
CURL_RC=$?
set -e

echo "[smoke] Telemetry POST curl exit code: $CURL_RC"
echo "[smoke] Telemetry POST HTTP status: $HTTP_CODE"
echo "[smoke] Telemetry POST response body:"
cat /tmp/telemetry-response.json || true
echo

if [ "$CURL_RC" -ne 0 ]; then
  echo "[smoke] Telemetry POST failed at network/connection level"
  exit 1
fi

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
  echo "[smoke] Telemetry POST returned non-2xx status"
  exit 1
fi

echo "[smoke] Telemetry POST returned success"

echo "[smoke] Fetching device status from device-state-svc..."
set +e
STATUS_HTTP_CODE=$(curl -s -o /tmp/status-response.json -w "%{http_code}" \
  http://device-state-svc:8080/devices/smoke-test-device/status)
STATUS_RC=$?
set -e

echo "[smoke] Device status curl exit code: $STATUS_RC"
echo "[smoke] Device status HTTP status: $STATUS_HTTP_CODE"
echo "[smoke] Device status response body:"
cat /tmp/status-response.json || true
echo

if [ "$STATUS_RC" -ne 0 ]; then
  echo "[smoke] Device status request failed at network/connection level"
  exit 1
fi

if [ "$STATUS_HTTP_CODE" -lt 200 ] || [ "$STATUS_HTTP_CODE" -ge 300 ]; then
  echo "[smoke] Device status returned non-2xx status"
  exit 1
fi

echo "[smoke] Device status fetch returned success"

echo "[smoke] All smoke tests passed."
'
  # IMPORTANT: no --rm here so we can inspect logs if it fails
  kubectl run telemetry-smoke-test \
    -n "$NAMESPACE" \
    --restart=Never \
    --image=curlimages/curl:8.10.1 \
    --rm -i \
    --command -- sh -c "$SMOKE_SCRIPT"
}

### Flags / arguments ##########################################################

SKIP_BUILD=false
SKIP_TESTS=false
SKIP_IMAGES=false
SKIP_SMOKE=false
CLUSTER_ONLY=false
SMOKE_ONLY=false
REBUILD_AGENT=false
REBUILD_DEVICE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=true
      ;;
    --skip-tests)
      SKIP_TESTS=true
      ;;
    --skip-images)
      SKIP_IMAGES=true
      ;;
    --skip-smoke)
      SKIP_SMOKE=true
      ;;
    --cluster-only)
      CLUSTER_ONLY=true
      ;;
    --smoke-only)
      SMOKE_ONLY=true
      ;;
    --rebuild-agent)
      REBUILD_AGENT=true
      ;;
    --rebuild-device)
      REBUILD_DEVICE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1 (use --help for usage)"
      ;;
  esac
  shift
done

# Mode compatibility checks
if [ "$SMOKE_ONLY" = true ] && [ "$CLUSTER_ONLY" = true ]; then
  fail "Use either --smoke-only or --cluster-only, not both."
fi

if [ "$SMOKE_ONLY" = true ] && { [ "$REBUILD_AGENT" = true ] || [ "$REBUILD_DEVICE" = true ]; }; then
  fail "--smoke-only cannot be combined with --rebuild-agent or --rebuild-device."
fi

if [ "$CLUSTER_ONLY" = true ] && { [ "$REBUILD_AGENT" = true ] || [ "$REBUILD_DEVICE" = true ]; }; then
  fail "--cluster-only cannot be combined with --rebuild-agent or --rebuild-device."
fi

REBUILD_MODE=false
if [ "$REBUILD_AGENT" = true ] || [ "$REBUILD_DEVICE" = true ]; then
  REBUILD_MODE=true
fi

### Pre-flight checks ##########################################################

log "Checking required commands"

if [ "$SMOKE_ONLY" = true ]; then
  # Smoke-only: just kubectl is required
  require_cmd kubectl

elif [ "$REBUILD_MODE" = true ]; then
  # Rebuild single service(s) on existing cluster
  require_cmd kind
  require_cmd kubectl
  require_cmd docker
  require_cmd java
  # gradlew will be used below

else
  # Normal / cluster-only full reset
  require_cmd kind
  require_cmd kubectl
  require_cmd docker
  require_cmd helm
  require_cmd java
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$SMOKE_ONLY" = false ]; then
  if [ "$REBUILD_MODE" = false ]; then
    # Full / cluster-only: need kind config and both service dirs
    if [ ! -f "$KIND_CONFIG" ]; then
      fail "Kind config file not found at '$KIND_CONFIG'"
    fi

    if [ "$CLUSTER_ONLY" = false ]; then
      if [ ! -d "agent-ingest-svc" ] || [ ! -d "device-state-svc" ]; then
        fail "Service directories 'agent-ingest-svc' and 'device-state-svc' not found at repo root. Check repo layout."
      fi
    fi
  else
    # Rebuild mode: cluster & namespace must already exist
    if ! kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
      fail "kind cluster '$KIND_CLUSTER_NAME' not found. Run a full reset first."
    fi
    if ! kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
      fail "Namespace '$NAMESPACE' not found. Run a full deploy before using --rebuild-*."
    fi
    if [ "$REBUILD_AGENT" = true ] && [ ! -d "agent-ingest-svc" ]; then
      fail "Directory 'agent-ingest-svc' not found at repo root."
    fi
    if [ "$REBUILD_DEVICE" = true ] && [ ! -d "device-state-svc" ]; then
      fail "Directory 'device-state-svc' not found at repo root."
    fi
  fi
fi

### Smoke-only short-circuit ###################################################

if [ "$SMOKE_ONLY" = true ]; then
  log "Smoke-only mode: running smoke tests against existing namespace '$NAMESPACE'"
  run_smoke_tests
  log "Smoke-only run completed 🎉"
  exit 0
fi

### 1. Cluster handling ########################################################

if [ "$REBUILD_MODE" = true ]; then
  log "Rebuild mode: using existing kind cluster '$KIND_CLUSTER_NAME' (no reset)"
  # No cluster delete/create here
else
  # Full / cluster-only path
  if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
    log "Deleting existing kind cluster '$KIND_CLUSTER_NAME'"
    kind delete cluster --name "$KIND_CLUSTER_NAME"
  fi

  log "Creating kind cluster '$KIND_CLUSTER_NAME' using $KIND_CONFIG"
  kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG"

  log "kind cluster info"
  kubectl cluster-info

  # If user only wants cluster recreated, stop here.
  if [ "$CLUSTER_ONLY" = true ]; then
    log "Cluster-only mode: skipping Gradle, Docker, Helm deploy, and smoke tests"
    exit 0
  fi
fi

### 2. Build Java services #####################################################

if [ "$SKIP_BUILD" = true ]; then
  log "Skipping Gradle build step (per --skip-build)"
else
  if [ "$REBUILD_MODE" = true ]; then
    log "Building selected Java services with Gradle (rebuild mode)"

    if [ "$SKIP_TESTS" = true ]; then
      log "Gradle will skip tests (per --skip-tests)"
      if [ "$REBUILD_AGENT" = true ]; then
        ./gradlew :agent-ingest-svc:build -x test
      fi
      if [ "$REBUILD_DEVICE" = true ]; then
        ./gradlew :device-state-svc:build -x test
      fi
    else
      if [ "$REBUILD_AGENT" = true ]; then
        ./gradlew :agent-ingest-svc:build
      fi
      if [ "$REBUILD_DEVICE" = true ]; then
        ./gradlew :device-state-svc:build
      fi
    fi

  else
    log "Building Java services with Gradle (full build)"
    if [ "$SKIP_TESTS" = true ]; then
      log "Gradle will skip tests (per --skip-tests)"
      ./gradlew :agent-ingest-svc:build :device-state-svc:build -x test
    else
      ./gradlew :agent-ingest-svc:build :device-state-svc:build
    fi
  fi
fi

### 3. Build Docker images #####################################################

if [ "$SKIP_IMAGES" = true ]; then
  log "Skipping Docker image builds (per --skip-images) – assuming images already exist"
else
  if [ "$REBUILD_MODE" = true ]; then
    if [ "$REBUILD_AGENT" = true ]; then
      log "Building Docker image for agent-ingest-svc: $AGENT_IMAGE"
      docker build -t "$AGENT_IMAGE" agent-ingest-svc
    fi
    if [ "$REBUILD_DEVICE" = true ]; then
      log "Building Docker image for device-state-svc: $DEVICE_IMAGE"
      docker build -t "$DEVICE_IMAGE" device-state-svc
    fi
  else
    log "Building Docker image for agent-ingest-svc: $AGENT_IMAGE"
    docker build -t "$AGENT_IMAGE" agent-ingest-svc

    log "Building Docker image for device-state-svc: $DEVICE_IMAGE"
    docker build -t "$DEVICE_IMAGE" device-state-svc
  fi
fi

### 4. Load images into kind ###################################################

log "Loading images into kind cluster '$KIND_CLUSTER_NAME'"

if [ "$REBUILD_MODE" = true ]; then
  if [ "$REBUILD_AGENT" = true ]; then
    kind load docker-image "$AGENT_IMAGE" --name "$KIND_CLUSTER_NAME"
  fi
  if [ "$REBUILD_DEVICE" = true ]; then
    kind load docker-image "$DEVICE_IMAGE" --name "$KIND_CLUSTER_NAME"
  fi
else
  kind load docker-image "$AGENT_IMAGE" --name "$KIND_CLUSTER_NAME"
  kind load docker-image "$DEVICE_IMAGE" --name "$KIND_CLUSTER_NAME"
fi

### 5. Full deploy path (ingress + Helm) ######################################

if [ "$REBUILD_MODE" = false ]; then
  log "Installing NGINX ingress controller (if not already present)"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  log "Waiting for ingress-nginx controller pod to be Ready"
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s

  # (Optional but nice) wait for admission jobs to finish
  log "Waiting for ingress-nginx admission jobs to complete"
  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-create \
    --timeout=120s || true

  kubectl wait --namespace ingress-nginx \
    --for=condition=complete job/ingress-nginx-admission-patch \
    --timeout=120s || true

  log "Ingress-nginx status:"
kubectl get pods -n ingress-nginx
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io | grep nginx || true

log "Probing ingress-nginx admission webhook readiness from inside the cluster"
kubectl run ingress-webhook-wait \
  -n ingress-nginx \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  --rm -i \
  --command -- sh -c '
    set -e
    SVC="https://ingress-nginx-controller-admission.ingress-nginx.svc:443"
    for i in $(seq 1 30); do
      echo "[probe] [$i] Trying to connect to $SVC ..."
      # -k: ignore TLS validation; we only care that something is listening
      if curl -sk "$SVC" >/dev/null 2>&1; then
        echo "[probe] Webhook endpoint is reachable."
        exit 0
      fi
      sleep 2
    done
    echo "[probe] Webhook endpoint is NOT reachable after retries."
    exit 1
  '

log "Updating Helm chart dependencies"
helm dependency update "$HELM_CHART_PATH"

log "Deploying Helm release '$HELM_RELEASE' from chart '$HELM_CHART_PATH' into namespace '$NAMESPACE'"

helm upgrade --install "$HELM_RELEASE" "$HELM_CHART_PATH" \
  -n "$NAMESPACE" \
  --create-namespace \
  --set agent-ingest-svc.image="$AGENT_IMAGE" \
  --set device-state-svc.image="$DEVICE_IMAGE" \
  --wait \
  --timeout 10m

  log "Waiting for Oracle StatefulSet to be ready"
  kubectl rollout status statefulset/oracle-db -n "$NAMESPACE" --timeout=600s

  log "Waiting for agent-ingest-svc deployment to be ready"
  kubectl rollout status deployment/agent-ingest-svc -n "$NAMESPACE" --timeout=300s

  log "Waiting for device-state-svc deployment to be ready"
  kubectl rollout status deployment/device-state-svc -n "$NAMESPACE" --timeout=300s

  log "Current pods in namespace '$NAMESPACE'"
  kubectl get pods -n "$NAMESPACE"

else
  ### 6. Rebuild-mode redeploy #################################################
  log "Rebuild mode: restarting updated deployments"

  if [ "$REBUILD_AGENT" = true ]; then
    log "Rolling out updated deployment: agent-ingest-svc"
    kubectl rollout restart deployment/agent-ingest-svc -n "$NAMESPACE"
    kubectl rollout status  deployment/agent-ingest-svc -n "$NAMESPACE" --timeout=300s
  fi

  if [ "$REBUILD_DEVICE" = true ]; then
    log "Rolling out updated deployment: device-state-svc"
    kubectl rollout restart deployment/device-state-svc -n "$NAMESPACE"
    kubectl rollout status  deployment/device-state-svc -n "$NAMESPACE" --timeout=300s
  fi

  log "Current pods in namespace '$NAMESPACE' after rebuild"
  kubectl get pods -n "$NAMESPACE"
fi

### 7. Smoke tests #############################################################

if [ "$SKIP_SMOKE" = true ]; then
  log "Skipping smoke tests (per --skip-smoke)"
else
  run_smoke_tests
fi

### 8. Summary #################################################################

log "All components are up and running${SKIP_SMOKE:+ (smoke tests skipped)} 🎉"
echo "You can now port-forward services, for example:"
echo "  kubectl port-forward svc/agent-ingest-svc -n $NAMESPACE 8080:8080"
echo "Then hit: http://localhost:8080/actuator/health"
