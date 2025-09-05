#!/usr/bin/env bash

# cluster-info.sh - Show detailed cluster information
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
    local name="${1:-}"
    
    if [ -z "$name" ]; then
        # Show current context info
        local current_context
        current_context=$(get_current_context)
        
        if [[ "$current_context" == kind-* ]]; then
            name=${current_context#kind-}
            log_info "Using current context: $current_context"
        else
            log_error "No cluster specified and current context is not a Kind cluster"
            log_info "Usage: cluster-info.sh CLUSTER_NAME"
            exit 1
        fi
    fi
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        exit 1
    fi
    
    local context="kind-$name"
    
    log_header "Cluster Information: $name"
    
    # Basic info
    echo "Context: $context"
    
    # Metadata
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    if [ -f "$meta_file" ]; then
        echo "Profile: $(grep '^profile=' "$meta_file" | cut -d'=' -f2 || echo 'unknown')"
        echo "Created: $(grep '^created=' "$meta_file" | cut -d'=' -f2 || echo 'unknown')"
    fi
    
    echo
    
    # Cluster info
    log_info "Cluster Details:"
    kubectl cluster-info --context "$context"
    
    echo
    
    # Nodes
    log_info "Nodes:"
    kubectl get nodes --context "$context" -o wide
    
    echo
    
    # System pods
    log_info "System Pods:"
    kubectl get pods -n kube-system --context "$context"
    
    # Flux status if installed
    if kubectl get namespace flux-system --context "$context" >/dev/null 2>&1; then
        echo
        log_info "Flux Status:"
        kubectl get pods -n flux-system --context "$context" 2>/dev/null || log_warning "Flux not accessible"
    fi
    
    echo
    
    # Health check
    validate_cluster_health "$name"
}

main "$@"