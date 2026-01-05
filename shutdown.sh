#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Telemetry Platform shutdown script (kind + k8s cleanup)
# ==============================================================================

KIND_CLUSTER_NAME="telemetry"
NAMESPACE="telemetry"
HELM_RELEASE="telemetry-platform"

AGENT_IMAGE="telemetry/agent-ingest-svc:local"
DEVICE_IMAGE="telemetry/device-state-svc:local"

log() {
  printf '\n==> %s\n' "$*"
}

### 1. Uninstall Helm release ##################################################

if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  if helm status "$HELM_RELEASE" -n "$NAMESPACE" >/dev/null 2>&1; then
    log "Uninstalling Helm release '$HELM_RELEASE' from namespace '$NAMESPACE'"
    helm uninstall "$HELM_RELEASE" -n "$NAMESPACE"
  else
    log "Helm release '$HELM_RELEASE' not found – skipping"
  fi
else
  log "Namespace '$NAMESPACE' not found – skipping Helm uninstall"
fi

### 2. Remove ingress-nginx #####################################################

if kubectl get ns ingress-nginx >/dev/null 2>&1; then
  log "Deleting ingress-nginx controller"
  kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || true

  log "Waiting briefly for ingress-nginx namespace to terminate"
  kubectl delete ns ingress-nginx --timeout=60s || true
else
  log "ingress-nginx namespace not present – skipping"
fi

### 3. Delete kind cluster ######################################################

if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
  log "Deleting kind cluster '$KIND_CLUSTER_NAME'"
  kind delete cluster --name "$KIND_CLUSTER_NAME"
else
  log "kind cluster '$KIND_CLUSTER_NAME' not found – nothing to delete"
fi

### 4. Optional: clean local Docker images #####################################

if docker image inspect "$AGENT_IMAGE" >/dev/null 2>&1; then
  log "Removing Docker image $AGENT_IMAGE"
  docker rmi "$AGENT_IMAGE" || true
fi

if docker image inspect "$DEVICE_IMAGE" >/dev/null 2>&1; then
  log "Removing Docker image $DEVICE_IMAGE"
  docker rmi "$DEVICE_IMAGE" || true
fi

### 5. Summary #################################################################

log "Telemetry Platform shutdown complete 🧹"
echo "Cluster, Helm releases, ingress, and local images cleaned up."
