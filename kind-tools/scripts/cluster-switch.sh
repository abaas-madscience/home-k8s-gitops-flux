#!/usr/bin/env bash

# cluster-switch.sh - Switch kubectl context to Kind cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
    local name="$1"
    
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        exit 1
    fi
    
    local context="kind-$name"
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        kind get clusters
        exit 1
    fi
    
    log_info "Switching to cluster '$name'..."
    kubectl config use-context "$context"
    
    # Verify the switch worked
    local current_context
    current_context=$(get_current_context)
    
    if [ "$current_context" = "$context" ]; then
        log_success "Switched to cluster '$name'"
        
        # Show basic cluster info
        kubectl cluster-info --context "$context"
    else
        log_error "Failed to switch context"
        exit 1
    fi
}

main "$@"