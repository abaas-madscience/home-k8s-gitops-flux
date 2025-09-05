#!/usr/bin/env bash

# cluster-list.sh - List Kind clusters with metadata
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
    log_header "Kind Clusters"
    
    local clusters
    clusters=$(kind get clusters 2>/dev/null) || {
        log_warning "No Kind clusters found"
        return 0
    }
    
    local current_context
    current_context=$(get_current_context)
    
    printf "%-15s %-12s %-10s %-15s %s\n" "NAME" "STATUS" "PROFILE" "CREATED" "CONTEXT"
    printf "%s\n" "$(printf '%.0s-' {1..70})"
    
    while IFS= read -r cluster; do
        [ -z "$cluster" ] && continue
        
        local status="Unknown"
        local profile="unknown"
        local created="unknown"
        local context_marker=" "
        
        # Check if this is the current context
        if [ "$current_context" = "kind-$cluster" ]; then
            context_marker="*"
        fi
        
        # Get cluster status
        if kubectl cluster-info --context "kind-$cluster" >/dev/null 2>&1; then
            if validate_cluster_health "$cluster" >/dev/null 2>&1; then
                status="Ready"
            else
                status="Degraded"
            fi
        else
            status="Not Ready"
        fi
        
        # Get metadata if available
        local meta_file="$HOME/.kind-dev/clusters/$cluster.meta"
        if [ -f "$meta_file" ]; then
            profile=$(grep "^profile=" "$meta_file" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
            created=$(grep "^created=" "$meta_file" 2>/dev/null | cut -d'=' -f2 | cut -d'T' -f1 || echo "unknown")
        fi
        
        printf "%s%-14s %-12s %-10s %-15s\n" "$context_marker" "$cluster" "$status" "$profile" "$created"
        
    done <<< "$clusters"
    
    echo
    log_info "Current context: $current_context"
    log_info "* indicates current kubectl context"
}

main "$@"