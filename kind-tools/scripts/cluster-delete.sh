#!/usr/bin/env bash

# cluster-delete.sh - Delete Kind cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
    local name="$1"
    
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        exit 1
    fi
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        exit 1
    fi
    
    log_warning "This will permanently delete cluster '$name'"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    log_info "Deleting cluster '$name'..."
    kind delete cluster --name "$name"
    
    # Clean up metadata
    rm -f "$HOME/.kind-dev/clusters/$name.meta"
    rm -f "$HOME/.kind-dev/clusters/$name-config.yaml"
    
    log_success "Cluster '$name' deleted successfully"
}

main "$@"