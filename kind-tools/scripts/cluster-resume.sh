#!/usr/bin/env bash

# cluster-resume.sh - Resume suspended Kind cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

resume_cluster() {
    local name="$1"
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        return 1
    fi
    
    log_info "Resuming cluster '$name'..."
    
    # Get all containers for this cluster (including stopped ones)
    local containers
    containers=$(docker ps -a --filter "label=io.x-k8s.kind.cluster=$name" --format "{{.Names}}" | tr '\n' ' ')
    
    if [ -z "$containers" ]; then
        log_error "No containers found for cluster '$name'"
        return 1
    fi
    
    log_info "Starting containers: $containers"
    
    # Start all cluster containers in the right order (control-plane first)
    local control_plane_container
    control_plane_container=$(echo "$containers" | tr ' ' '\n' | grep "control-plane" | head -1 || echo "")
    
    if [ -n "$control_plane_container" ]; then
        log_info "Starting control plane: $control_plane_container"
        docker start "$control_plane_container" >/dev/null 2>&1 || log_error "Failed to start $control_plane_container"
        
        # Wait a moment for control plane to initialize
        sleep 5
    fi
    
    # Start worker nodes
    local worker_containers
    worker_containers=$(echo "$containers" | tr ' ' '\n' | grep -v "control-plane" || echo "")
    
    if [ -n "$worker_containers" ]; then
        for container in $worker_containers; do
            log_info "Starting worker: $container"
            docker start "$container" >/dev/null 2>&1 || log_warning "Failed to start $container"
        done
    fi
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to become ready..."
    if wait_for_cluster "$name"; then
        log_success "Cluster '$name' resumed successfully"
    else
        log_warning "Cluster containers started but cluster may not be fully ready yet"
    fi
    
    # Update metadata
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    if [ -f "$meta_file" ]; then
        # Remove suspended status
        sed -i "/^suspended=/d" "$meta_file"
        sed -i "/^suspended_at=/d" "$meta_file"
        
        # Add resume timestamp
        if grep -q "^last_resumed=" "$meta_file"; then
            sed -i "s/^last_resumed=.*/last_resumed=$(date -Iseconds)/" "$meta_file"
        else
            echo "last_resumed=$(date -Iseconds)" >> "$meta_file"
        fi
    fi
    
    # Set kubectl context
    kubectl config use-context "kind-$name" >/dev/null 2>&1 || log_warning "Failed to set kubectl context"
    
    log_info "Context: kind-$name"
}

main() {
    local name="${1:-}"
    
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        log_info "Usage: cluster-resume.sh CLUSTER_NAME"
        exit 1
    fi
    
    resume_cluster "$name"
}

main "$@"