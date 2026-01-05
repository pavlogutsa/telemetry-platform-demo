#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Local dev launcher: kind + build/images + load + Terragrunt apply/destroy
#
# Usage:
#   ./terragrunt_local.sh up
#   ./terragrunt_local.sh down
#
# Optional env vars:
#   SKIP_BUILD=true        # skip Gradle build
#   SKIP_TESTS=true        # skip Gradle tests (only used if SKIP_BUILD!=true)
#   SKIP_IMAGES=true       # skip docker build (assumes images already exist locally)
#   AUTO_APPROVE=true      # pass --auto-approve to terragrunt apply/destroy
#
# Notes:
# - Terragrunt does NOT build or load images, so we do it here.
# - This script assumes your Terragrunt local root is: infra/live/dev
# - It assumes your service dirs are at repo root: agent-ingest-svc, device-state-svc
# ==============================================================================

KIND_CLUSTER_NAME="telemetry"
KIND_CONFIG="kind-config.yaml"

TG_ROOT="infra/live/dev"

NAMESPACE="telemetry"

AGENT_IMAGE="telemetry/agent-ingest-svc:local"
DEVICE_IMAGE="telemetry/device-state-svc:local"

SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"
SKIP_IMAGES="${SKIP_IMAGES:-false}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

log() { printf '\n==> %s\n' "$*"; }
fail() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' not found in PATH"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

ensure_kind_cluster() {
  require_cmd kind
  require_cmd kubectl

  if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
    log "kind cluster '$KIND_CLUSTER_NAME' already exists"
  else
    [ -f "$KIND_CONFIG" ] || fail "Kind config not found: $KIND_CONFIG"
    log "Creating kind cluster '$KIND_CLUSTER_NAME' using $KIND_CONFIG"
    kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG"
  fi

  log "Using kube context:"
  kubectl config current-context

  log "Cluster info:"
  kubectl cluster-info
}

build_services() {
  require_cmd java

  if [ "$SKIP_BUILD" = "true" ]; then
    log "Skipping Gradle build (SKIP_BUILD=true)"
    return 0
  fi

  [ -x "./gradlew" ] || fail "gradlew not found/executable at repo root"

  log "Building Java services with Gradle"
  if [ "$SKIP_TESTS" = "true" ]; then
    log "Skipping tests (SKIP_TESTS=true)"
    ./gradlew :agent-ingest-svc:build :device-state-svc:build -x test
  else
    ./gradlew :agent-ingest-svc:build :device-state-svc:build
  fi
}

build_images() {
  require_cmd docker

  if [ "$SKIP_IMAGES" = "true" ]; then
    log "Skipping Docker builds (SKIP_IMAGES=true) – expecting images already exist locally"
    return 0
  fi

  [ -d "agent-ingest-svc" ] || fail "Missing directory: agent-ingest-svc"
  [ -d "device-state-svc" ] || fail "Missing directory: device-state-svc"

  log "Building Docker image: $AGENT_IMAGE"
  docker build -t "$AGENT_IMAGE" agent-ingest-svc

  log "Building Docker image: $DEVICE_IMAGE"
  docker build -t "$DEVICE_IMAGE" device-state-svc
}

load_images_into_kind() {
  require_cmd kind

  log "Loading images into kind cluster '$KIND_CLUSTER_NAME'"
  kind load docker-image "$AGENT_IMAGE" --name "$KIND_CLUSTER_NAME"
  kind load docker-image "$DEVICE_IMAGE" --name "$KIND_CLUSTER_NAME"
}

terragrunt_apply() {
  require_cmd terragrunt

  log "Terragrunt init (local dev)"
  (cd "$TG_ROOT" && terragrunt run --all init --non-interactive)

  log "Terragrunt apply (local dev)"
  if [ "$AUTO_APPROVE" = "true" ]; then
    (cd "$TG_ROOT" && terragrunt run --all apply --auto-approve --non-interactive)
  else
    (cd "$TG_ROOT" && terragrunt run --all apply --non-interactive)
  fi
}

terragrunt_destroy() {
  require_cmd terragrunt

  log "Terragrunt destroy (local dev)"
  if [ "$AUTO_APPROVE" = "true" ]; then
    (cd "$TG_ROOT" && terragrunt run --all destroy --auto-approve --non-interactive)
  else
    (cd "$TG_ROOT" && terragrunt run --all destroy --non-interactive)
  fi
}


delete_kind_cluster() {
  require_cmd kind

  if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
    log "Deleting kind cluster '$KIND_CLUSTER_NAME'"
    kind delete cluster --name "$KIND_CLUSTER_NAME"
  else
    log "kind cluster '$KIND_CLUSTER_NAME' not found – nothing to delete"
  fi
}

usage() {
  cat <<EOF
Usage:
  $0 up
  $0 down

Optional env vars:
  SKIP_BUILD=true
  SKIP_TESTS=true
  SKIP_IMAGES=true
  AUTO_APPROVE=true
EOF
}

cmd="${1:-}"
case "$cmd" in
  up)
    log "UP: kind + build + images + load + terragrunt apply"
    ensure_kind_cluster
    build_services
    build_images
    load_images_into_kind
    terragrunt_apply

    log "Status:"
    kubectl get ns "$NAMESPACE" >/dev/null 2>&1 && kubectl get pods -n "$NAMESPACE" || true
    log "Up complete 🎉"
    ;;
  down)
    log "DOWN: terragrunt destroy + delete kind cluster"
    # Destroy platform resources first, then wipe the cluster.
    terragrunt_destroy
    delete_kind_cluster
    log "Down complete 🧹"
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    fail "Unknown command: '$cmd' (use: up | down)"
    ;;
esac
