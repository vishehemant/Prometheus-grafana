#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

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
error() { echo -e "${RED}[ERROR]${NC} $*"; }
header(){ echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

check_prerequisites() {
    header "Checking Prerequisites"

    local missing=()

    if ! command -v docker &>/dev/null; then
        missing+=("docker")
    else
        log "Docker: $(docker --version)"
    fi

    if ! command -v kind &>/dev/null; then
        missing+=("kind")
        warn "Kind not found. Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    else
        log "Kind: $(kind version)"
    fi

    if ! command -v kubectl &>/dev/null; then
        missing+=("kubectl")
        warn "kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/"
    else
        log "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    fi

    if ! command -v helm &>/dev/null; then
        missing+=("helm")
        warn "Helm not found. Install: https://helm.sh/docs/intro/install/"
    else
        log "Helm: $(helm version --short)"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Please install them and re-run this script."
        exit 1
    fi

    log "All prerequisites satisfied."
}

create_kind_cluster() {
    header "Creating Kind Cluster: ${CLUSTER_NAME}"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        warn "Cluster '${CLUSTER_NAME}' already exists."
        read -rp "Delete and recreate? (y/N): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            log "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            log "Using existing cluster."
            kubectl cluster-info --context "kind-${CLUSTER_NAME}"
            return
        fi
    fi

    log "Creating Kind cluster with 1 control-plane + 2 worker nodes..."
    kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/kind/kind-config.yaml"

    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    log "Cluster created successfully."
}

build_and_load_images() {
    header "Building and Loading Docker Images into Kind"

    log "Building Flask app image..."
    docker build -t monitoring-lab-app:latest "${ROOT_DIR}/app/"

    log "Building traffic generator image..."
    docker build -t monitoring-lab-traffic:latest "${ROOT_DIR}/scripts/" -f "${ROOT_DIR}/scripts/Dockerfile"

    log "Loading images into Kind cluster..."
    kind load docker-image monitoring-lab-app:latest --name "${CLUSTER_NAME}"
    kind load docker-image monitoring-lab-traffic:latest --name "${CLUSTER_NAME}"

    log "Images loaded successfully."
}

deploy_helm_chart() {
    header "Deploying Monitoring Lab Helm Chart"

    log "Installing Helm chart..."
    helm upgrade --install "${RELEASE_NAME}" "${ROOT_DIR}/helm-chart/monitoring-lab/" \
        --create-namespace \
        --namespace "${NAMESPACE}" \
        --wait \
        --timeout 5m

    log "Helm chart deployed successfully."
}

wait_for_pods() {
    header "Waiting for All Pods to be Ready"

    log "Waiting up to 5 minutes for pods to become ready..."

    local max_wait=300
    local elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        local not_ready
        not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -cvE "Running|Completed" || true)

        if [ "$not_ready" -eq 0 ] 2>/dev/null; then
            log "All pods are running!"
            break
        fi

        echo -ne "\r  Waiting... (${elapsed}s / ${max_wait}s) - ${not_ready} pod(s) not ready"
        sleep 5
        elapsed=$((elapsed + 5))
    done

    echo ""
    kubectl get pods -n "${NAMESPACE}" -o wide
}

print_access_info() {
    header "Access Information"

    echo -e "${GREEN}Service URLs (via Kind NodePort mappings):${NC}"
    echo ""
    echo -e "  Flask App:      ${BLUE}http://localhost:5000${NC}"
    echo -e "  Prometheus:     ${BLUE}http://localhost:9090${NC}"
    echo -e "  Grafana:        ${BLUE}http://localhost:3000${NC}  (admin/admin)"
    echo -e "  Alertmanager:   ${BLUE}http://localhost:9093${NC}"
    echo -e "  Jaeger:         ${BLUE}http://localhost:16686${NC}"
    echo ""
    echo -e "${GREEN}Alternative: use kubectl port-forward:${NC}"
    echo ""
    echo "  kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/prometheus 9090:9090"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/alertmanager 9093:9093"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/jaeger 16686:16686"
    echo "  kubectl port-forward -n ${NAMESPACE} svc/app 5000:5000"
    echo ""
    echo -e "${GREEN}Useful kubectl commands:${NC}"
    echo ""
    echo "  kubectl get pods -n ${NAMESPACE}"
    echo "  kubectl get svc -n ${NAMESPACE}"
    echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=app -f"
    echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=traffic-generator -f"
    echo ""
}

main() {
    header "Monitoring Lab - Kind + Helm Setup"
    check_prerequisites
    create_kind_cluster
    build_and_load_images
    deploy_helm_chart
    wait_for_pods
    print_access_info
    log "Setup complete! Happy monitoring!"
}

main "$@"
