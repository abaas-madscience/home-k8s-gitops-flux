#!/usr/bin/env bash

# flux-bootstrap.sh - Bootstrap Flux GitOps on Kind cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Default values
DEFAULT_OWNER="abaas-madscience"
DEFAULT_REPO="home-k8s-gitops-flux"
DEFAULT_BRANCH="kind"
DEFAULT_PATH="clusters/kind"

bootstrap_flux() {
    local name="$1"
    local repo="${2:-}"
    local context="kind-$name"
    
    # Check if cluster exists and is accessible
    if ! kubectl cluster-info --context "$context" >/dev/null 2>&1; then
        log_error "Cluster '$name' is not accessible"
        return 1
    fi
    
    # Set context
    kubectl config use-context "$context"
    
    # Check for GITHUB_TOKEN
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_error "GITHUB_TOKEN environment variable is required"
        log_info "Export your GitHub personal access token:"
        log_info "  export GITHUB_TOKEN=your_token_here"
        return 1
    fi
    
    # Parse repo if provided, otherwise use defaults
    local owner="$DEFAULT_OWNER"
    local repo_name="$DEFAULT_REPO"
    
    if [ -n "$repo" ]; then
        if [[ "$repo" == *"/"* ]]; then
            owner=$(echo "$repo" | cut -d'/' -f1)
            repo_name=$(echo "$repo" | cut -d'/' -f2)
        else
            repo_name="$repo"
        fi
    fi
    
    log_header "Bootstrapping Flux on cluster: $name"
    log_info "Repository: $owner/$repo_name"
    log_info "Branch: $DEFAULT_BRANCH"
    log_info "Path: $DEFAULT_PATH"
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    if ! flux check --pre >/dev/null 2>&1; then
        log_error "Flux pre-flight checks failed"
        log_info "Install Flux CLI: https://fluxcd.io/flux/installation/"
        return 1
    fi
    
    # Bootstrap Flux
    log_info "Bootstrapping Flux GitOps..."
    flux bootstrap github \
        --owner="$owner" \
        --repository="$repo_name" \
        --branch="$DEFAULT_BRANCH" \
        --path="$DEFAULT_PATH" \
        --personal \
        --private=false \
        --components=source-controller,kustomize-controller,helm-controller,notification-controller
    
    # Wait for Flux system to be ready
    log_info "Waiting for Flux system to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux --namespace=flux-system --timeout=300s
    
    # Create kind-specific namespace and configurations
    create_kind_configs "$name"
    
    log_success "Flux GitOps bootstrapped successfully!"
    log_info "Repository URL: https://github.com/$owner/$repo_name/tree/$DEFAULT_BRANCH/$DEFAULT_PATH"
    
    # Show status
    flux get kustomizations -A
}

create_kind_configs() {
    local name="$1"
    
    log_info "Creating Kind-specific configurations..."
    
    # Create kind-specific namespace
    kubectl create namespace kind-dev --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap with cluster info
    kubectl create configmap cluster-info \
        --namespace=kind-dev \
        --from-literal=name="$name" \
        --from-literal=type="kind" \
        --from-literal=profile="${PROFILE_NAME:-unknown}" \
        --from-literal=created="$(date -Iseconds)" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Kind-specific configurations created"
}

# Check if Flux is already installed
check_flux_installation() {
    local context="$1"
    
    if kubectl get namespace flux-system --context "$context" >/dev/null 2>&1; then
        log_warning "Flux is already installed on this cluster"
        
        # Show current status
        log_info "Current Flux status:"
        kubectl get pods -n flux-system --context "$context"
        
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            return 1
        fi
    fi
    
    return 0
}

main() {
    local name="${1:-}"
    local repo="${2:-}"
    
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        log_info "Usage: flux-bootstrap.sh CLUSTER_NAME [REPOSITORY]"
        exit 1
    fi
    
    local context="kind-$name"
    
    # Check if flux CLI is available
    if ! command -v flux >/dev/null 2>&1; then
        log_error "Flux CLI not found"
        log_info "Install Flux CLI: https://fluxcd.io/flux/installation/"
        exit 1
    fi
    
    # Check existing installation
    if ! check_flux_installation "$context"; then
        exit 1
    fi
    
    # Bootstrap
    bootstrap_flux "$name" "$repo"
}

main "$@"