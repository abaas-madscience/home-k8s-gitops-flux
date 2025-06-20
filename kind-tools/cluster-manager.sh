#!/usr/bin/env bash

# kind-cluster-manager.sh
# Companion script for managing Kind clusters

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# List all Kind clusters
list_clusters() {
    log_info "Kind clusters:"
    kind get clusters 2>/dev/null || log_warning "No Kind clusters found"
}

# Delete cluster
delete_cluster() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        exit 1
    fi
    
    log_info "Deleting cluster '$name'..."
    kind delete cluster --name "$name"
    log_success "Cluster '$name' deleted"
}

# Switch context
switch_context() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Cluster name required"
        exit 1
    fi
    
    kubectl config use-context "kind-$name"
    log_success "Switched to cluster '$name'"
}

# Cluster info
cluster_info() {
    local name="$1"
    if [ -z "$name" ]; then
        # Show current context
        current=$(kubectl config current-context 2>/dev/null || echo "none")
        log_info "Current context: $current"
        return
    fi
    
    log_info "Cluster '$name' information:"
    kubectl cluster-info --context "kind-$name"
    echo
    kubectl get nodes --context "kind-$name"
}

usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

COMMANDS:
    list                    List all Kind clusters
    delete NAME             Delete a specific cluster
    switch NAME             Switch kubectl context to cluster
    info [NAME]             Show cluster info (current if no name provided)
    
EXAMPLES:
    $0 list
    $0 delete test-cluster
    $0 switch my-cluster
    $0 info test-cluster
EOF
}

case "${1:-}" in
    list)
        list_clusters
        ;;
    delete)
        delete_cluster "${2:-}"
        ;;
    switch)
        switch_context "${2:-}"
        ;;
    info)
        cluster_info "${2:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac