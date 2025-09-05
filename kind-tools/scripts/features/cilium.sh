#!/usr/bin/env bash

# cilium.sh - Cilium CNI installation for Kind

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

install_cilium() {
    log_info "Installing Cilium CNI..."
    
    # Check if cilium CLI is available
    if command -v cilium >/dev/null 2>&1; then
        install_cilium_cli
    else
        install_cilium_helm
    fi
}

install_cilium_cli() {
    log_info "Using Cilium CLI for installation..."
    
    cilium install \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set l2announcements.enabled=true \
        --set gatewayAPI.enabled=true \
        --set gatewayAPI.enableAlpn=true \
        --set gatewayAPI.enableAppProtocol=true \
        --set operator.replicas=1
    
    log_info "Waiting for Cilium to be ready..."
    cilium status --wait
    
    log_success "Cilium installed successfully with CLI"
}

install_cilium_helm() {
    log_info "Using Helm for Cilium installation..."
    
    add_helm_repo cilium https://helm.cilium.io/
    
    helm install cilium cilium/cilium --version 1.16.11 \
        --namespace kube-system \
        --set operator.replicas=1 \
        --set kubeProxyReplacement=true \
        --set l2announcements.enabled=true \
        --set ipam.mode=kubernetes \
        --set gatewayAPI.enabled=true \
        --set gatewayAPI.enableAlpn=true \
        --set gatewayAPI.enableAppProtocol=true
    
    log_info "Waiting for Cilium to be ready..."
    wait_for_pods "kube-system" "k8s-app=cilium" 300
    
    log_success "Cilium installed successfully with Helm"
}