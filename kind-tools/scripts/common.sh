#!/usr/bin/env bash

# common.sh - Shared functions for kind-dev scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}[KIND-DEV]${NC} $1"; }

# Check required dependencies
check_dependencies() {
    local missing_tools=()
    
    command -v kind >/dev/null 2>&1 || missing_tools+=("kind")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                kind)
                    echo "  kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                    ;;
                kubectl)
                    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                helm)
                    echo "  helm: https://helm.sh/docs/intro/install/"
                    ;;
                docker)
                    echo "  docker: https://docs.docker.com/get-docker/"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Wait for cluster to be ready
wait_for_cluster() {
    local name="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for cluster '$name' to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl cluster-info --context "kind-$name" >/dev/null 2>&1; then
            if kubectl get nodes --context "kind-$name" | grep -q "Ready"; then
                log_success "Cluster '$name' is ready!"
                return 0
            fi
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for cluster..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Cluster failed to become ready within timeout"
    return 1
}

# Wait for pods to be ready
wait_for_pods() {
    local namespace="$1"
    local selector="$2"
    local timeout="${3:-300}"
    
    log_info "Waiting for pods in namespace '$namespace' with selector '$selector'..."
    kubectl wait --for=condition=ready pod -l "$selector" --namespace="$namespace" --timeout="${timeout}s"
}

# Add Helm repository with force update
add_helm_repo() {
    local name="$1"
    local url="$2"
    
    log_info "Adding Helm repository: $name"
    helm repo add "$name" "$url" --force-update
    helm repo update
}

# Check if cluster exists
cluster_exists() {
    local name="$1"
    kind get clusters 2>/dev/null | grep -q "^$name$"
}

# Get current kubectl context
get_current_context() {
    kubectl config current-context 2>/dev/null || echo "none"
}

# Validate cluster health
validate_cluster_health() {
    local name="$1"
    local context="kind-$name"
    
    log_info "Validating cluster health for '$name'..."
    
    # Check nodes
    local nodes_ready=$(kubectl get nodes --context "$context" --no-headers | grep -c "Ready" || echo "0")
    local nodes_total=$(kubectl get nodes --context "$context" --no-headers | wc -l || echo "0")
    
    if [ "$nodes_ready" -eq "$nodes_total" ] && [ "$nodes_total" -gt 0 ]; then
        log_success "$nodes_ready/$nodes_total nodes ready"
    else
        log_warning "$nodes_ready/$nodes_total nodes ready"
    fi
    
    # Check system pods
    local system_pods_running=$(kubectl get pods -n kube-system --context "$context" --no-headers | grep -c "Running" || echo "0")
    local system_pods_total=$(kubectl get pods -n kube-system --context "$context" --no-headers | wc -l || echo "0")
    
    if [ "$system_pods_running" -eq "$system_pods_total" ] && [ "$system_pods_total" -gt 0 ]; then
        log_success "$system_pods_running/$system_pods_total system pods running"
    else
        log_warning "$system_pods_running/$system_pods_total system pods running"
    fi
    
    # Check cluster info
    if kubectl cluster-info --context "$context" >/dev/null 2>&1; then
        log_success "Cluster API server accessible"
        return 0
    else
        log_error "Cluster API server not accessible"
        return 1
    fi
}

# Get cluster metadata
get_cluster_meta() {
    local name="$1"
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    
    if [ -f "$meta_file" ]; then
        cat "$meta_file"
    else
        echo "No metadata found for cluster: $name"
    fi
}