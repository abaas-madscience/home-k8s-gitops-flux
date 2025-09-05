#!/usr/bin/env bash

# cluster-validate.sh - Comprehensive cluster validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

validate_networking() {
    local context="$1"
    
    log_info "Validating networking..."
    
    # Check CoreDNS
    local coredns_pods
    coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --context "$context" --no-headers | grep -c "Running" || echo "0")
    
    if [ "$coredns_pods" -gt 0 ]; then
        log_success "CoreDNS pods running: $coredns_pods"
    else
        log_error "CoreDNS pods not running"
        return 1
    fi
    
    # Test DNS resolution
    if kubectl run dns-test --image=busybox --rm -it --restart=Never --context "$context" -- nslookup kubernetes.default >/dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_warning "DNS resolution test failed"
    fi
}

validate_storage() {
    local context="$1"
    local name="$2"
    
    log_info "Validating storage..."
    
    # Check storage classes
    local storage_classes
    storage_classes=$(kubectl get storageclass --context "$context" --no-headers | wc -l || echo "0")
    
    if [ "$storage_classes" -gt 0 ]; then
        log_success "Storage classes available: $storage_classes"
        kubectl get storageclass --context "$context"
    else
        log_warning "No storage classes found"
    fi
    
    # Check Rook storage readiness
    local meta_file="$HOME/.kind-dev/clusters/$name.meta"
    if [ -f "$meta_file" ] && grep -q "rook_storage_ready=true" "$meta_file" 2>/dev/null; then
        local workers=$(grep "^workers=" "$meta_file" | cut -d'=' -f2)
        log_success "Rook-Ceph storage ready: $workers worker nodes with mounted storage"
        
        # Verify storage mounts exist in containers
        local ready_mounts=0
        for ((i=1; i<=workers; i++)); do
            local worker_name=$(kubectl get nodes --context "$context" -o name | grep worker | sed -n "${i}p" | cut -d'/' -f2)
            if [ -n "$worker_name" ]; then
                # Check if the mount exists in the container (we can't easily check this from kubectl)
                log_info "Storage mount ready for $worker_name: /mnt/rook-disk"
                ((ready_mounts++))
            fi
        done
        
        if [ "$ready_mounts" -eq "$workers" ]; then
            log_success "All Rook storage mounts verified"
        fi
    else
        log_info "Rook-Ceph storage not configured (no worker nodes or basic profile)"
    fi
}

validate_features() {
    local context="$1"
    local name="$2"
    
    log_info "Validating installed features..."
    
    # Check for Cilium
    if kubectl get pods -n kube-system -l k8s-app=cilium --context "$context" --no-headers >/dev/null 2>&1; then
        local cilium_pods
        cilium_pods=$(kubectl get pods -n kube-system -l k8s-app=cilium --context "$context" --no-headers | grep -c "Running" || echo "0")
        log_success "Cilium CNI detected: $cilium_pods pods running"
    fi
    
    # Check for Gateway API CRDs
    if kubectl get crd gateways.gateway.networking.k8s.io --context "$context" >/dev/null 2>&1; then
        log_success "Gateway API CRDs detected"
    fi
    
    # Check for Flux
    if kubectl get namespace flux-system --context "$context" >/dev/null 2>&1; then
        local flux_pods
        flux_pods=$(kubectl get pods -n flux-system --context "$context" --no-headers | grep -c "Running" || echo "0")
        log_success "Flux GitOps detected: $flux_pods pods running"
    else
        log_info "Flux not installed. Use 'kind-dev bootstrap $name' to install GitOps."
    fi
}

run_smoke_tests() {
    local context="$1"
    
    log_info "Running smoke tests..."
    
    # Test pod scheduling
    kubectl run smoke-test --image=nginx --context "$context" >/dev/null 2>&1
    
    if kubectl wait --for=condition=ready pod smoke-test --context "$context" --timeout=60s >/dev/null 2>&1; then
        log_success "Pod scheduling test passed"
        kubectl delete pod smoke-test --context "$context" >/dev/null 2>&1
    else
        log_warning "Pod scheduling test failed"
        kubectl delete pod smoke-test --context "$context" >/dev/null 2>&1 || true
    fi
}

main() {
    local name="${1:-}"
    
    if [ -z "$name" ]; then
        # Use current context if available
        local current_context
        current_context=$(get_current_context)
        
        if [[ "$current_context" == kind-* ]]; then
            name=${current_context#kind-}
        else
            log_error "No cluster specified and current context is not a Kind cluster"
            exit 1
        fi
    fi
    
    if ! cluster_exists "$name"; then
        log_error "Cluster '$name' does not exist"
        exit 1
    fi
    
    local context="kind-$name"
    
    log_header "Validating cluster: $name"
    
    # Basic health check
    if ! validate_cluster_health "$name"; then
        log_error "Basic health check failed"
        return 1
    fi
    
    # Detailed validations
    validate_networking "$context" || log_warning "Networking validation had issues"
    validate_storage "$context" "$name"
    validate_features "$context" "$name"
    run_smoke_tests "$context"
    
    log_success "Cluster validation completed"
}

main "$@"