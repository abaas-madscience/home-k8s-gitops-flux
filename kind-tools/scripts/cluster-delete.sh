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
    
    # Get cluster info before deletion to determine number of workers
    local workers=0
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    local config_file="$HOME/.kind-dev/clusters/$name-config.yaml"
    
    # Try to determine number of workers from config file
    if [ -f "$config_file" ]; then
        workers=$(grep -c "role: worker" "$config_file" 2>/dev/null || echo "0")
    fi
    
    # Delete the kind cluster
    kind delete cluster --name "$name"
    
    # Clean up Rook storage directories
    if [ "$workers" -gt 0 ]; then
        log_info "Cleaning up Rook storage directories..."
        for ((i=1; i<=workers; i++)); do
            if [ -d "/tmp/rook-storage-$i" ]; then
                rm -rf "/tmp/rook-storage-$i"
                log_info "Removed storage directory: /tmp/rook-storage-$i"
            fi
        done
    fi
    
    # Clean up metadata
    rm -f "$meta_file"
    rm -f "$config_file"
    
    log_success "Cluster '$name' deleted successfully"
}

main "$@"