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
    
    printf "%-15s %-12s %-10s %-15s %-10s %s\n" "NAME" "STATUS" "PROFILE" "CREATED" "STATE" "CONTEXT"
    printf "%s\n" "$(printf '%.0s-' {1..80})"
    
    while IFS= read -r cluster; do
        [ -z "$cluster" ] && continue
        
        local status="Unknown"
        local profile="unknown"
        local created="unknown"
        local state="Active"
        local context_marker=" "
        
        # Check if this is the current context
        if [ "$current_context" = "kind-$cluster" ]; then
            context_marker="*"
        fi
        
        # Get metadata if available
        local meta_file="$HOME/.kind-dev/clusters/$cluster.meta"
        if [ -f "$meta_file" ]; then
            profile=$(grep "^profile=" "$meta_file" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
            created=$(grep "^created=" "$meta_file" 2>/dev/null | cut -d'=' -f2 | cut -d'T' -f1 || echo "unknown")
            
            # Check if suspended
            if grep -q "^suspended=true" "$meta_file" 2>/dev/null; then
                state="Suspended"
                status="Suspended"
            fi
        fi
        
        # Get cluster status (only if not suspended)
        if [ "$state" != "Suspended" ]; then
            if kubectl cluster-info --context "kind-$cluster" >/dev/null 2>&1; then
                if validate_cluster_health "$cluster" >/dev/null 2>&1; then
                    status="Ready"
                else
                    status="Degraded"
                fi
            else
                status="Not Ready"
            fi
        fi
        
        printf "%s%-14s %-12s %-10s %-15s %-10s\n" "$context_marker" "$cluster" "$status" "$profile" "$created" "$state"
        
    done <<< "$clusters"
    
    echo
    log_info "Current context: $current_context"
    log_info "* indicates current kubectl context"
}

main "$@"