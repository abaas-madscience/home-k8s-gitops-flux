#!/usr/bin/env bash

# cluster-suspend.sh - Suspend Kind cluster to save resources
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

suspend_cluster() {
    local name="$1"
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        return 1
    fi
    
    log_info "Suspending cluster '$name'..."
    
    # Get all containers for this cluster
    local containers
    containers=$(docker ps --filter "label=io.x-k8s.kind.cluster=$name" --format "{{.Names}}" | tr '\n' ' ')
    
    if [ -z "$containers" ]; then
        log_warning "No running containers found for cluster '$name'"
        return 0
    fi
    
    log_info "Stopping containers: $containers"
    
    # Stop all cluster containers
    for container in $containers; do
        log_info "Stopping container: $container"
        docker stop "$container" >/dev/null 2>&1 || log_warning "Failed to stop $container"
    done
    
    # Update metadata
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    if [ -f "$meta_file" ]; then
        # Add or update suspended status
        if grep -q "^suspended=" "$meta_file"; then
            sed -i "s/^suspended=.*/suspended=true/" "$meta_file"
        else
            echo "suspended=true" >> "$meta_file"
        fi
        
        # Add suspend timestamp
        if grep -q "^suspended_at=" "$meta_file"; then
            sed -i "s/^suspended_at=.*/suspended_at=$(date -Iseconds)/" "$meta_file"
        else
            echo "suspended_at=$(date -Iseconds)" >> "$meta_file"
        fi
    fi
    
    log_success "Cluster '$name' suspended successfully"
    log_info "Containers are stopped but preserved. Use 'kind-dev resume $name' to restart."
}

main() {
    local name="${1:-}"
    
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        log_info "Usage: cluster-suspend.sh CLUSTER_NAME"
        exit 1
    fi
    
    suspend_cluster "$name"
}

main "$@"