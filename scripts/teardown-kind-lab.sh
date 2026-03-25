#!/bin/bash
set -euo pipefail

CLUSTER_NAME="monitoring-lab"
NAMESPACE="monitoring"
RELEASE_NAME="monitoring-lab"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
header(){ echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

header "Monitoring Lab - Teardown"

if helm list -n "${NAMESPACE}" 2>/dev/null | grep -q "${RELEASE_NAME}"; then
    log "Uninstalling Helm release: ${RELEASE_NAME}"
    helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" || true
else
    warn "Helm release '${RELEASE_NAME}' not found (may already be removed)."
fi

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Deleting Kind cluster: ${CLUSTER_NAME}"
    kind delete cluster --name "${CLUSTER_NAME}"
else
    warn "Kind cluster '${CLUSTER_NAME}' not found."
fi

log "Cleaning up Docker images (optional)..."
docker rmi monitoring-lab-app:latest monitoring-lab-traffic:latest 2>/dev/null || true

log "Teardown complete."
