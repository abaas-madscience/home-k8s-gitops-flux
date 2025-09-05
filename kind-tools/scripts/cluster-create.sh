#!/usr/bin/env bash

# cluster-create.sh - Create Kind cluster based on profile
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parse YAML profile using yq or basic parsing
parse_profile() {
    local profile_file="$1"
    
    # Check if this is the Go-based yq (mikefarah/yq)
    if command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -q "mikefarah"; then
        parse_profile_yq_go "$profile_file"
    else
        # Use basic parsing for older yq versions or no yq
        parse_profile_basic "$profile_file"
    fi
}

parse_profile_yq_go() {
    local profile_file="$1"
    
    export CLUSTER_K8S_VERSION=$(yq eval '.cluster.k8sVersion // "1.32.0"' "$profile_file")
    export CLUSTER_CONTROL_PLANES=$(yq eval '.cluster.controlPlanes // 1' "$profile_file")
    export CLUSTER_WORKERS=$(yq eval '.cluster.workers // 2' "$profile_file")
    export CLUSTER_DISABLE_CNI=$(yq eval '.cluster.disableCNI // false' "$profile_file")
    export CLUSTER_DISABLE_KUBE_PROXY=$(yq eval '.cluster.disableKubeProxy // false' "$profile_file")
    
    # Features
    export FEATURE_CILIUM=$(yq eval '.features.cilium.enabled // false' "$profile_file")
    export FEATURE_GATEWAY_API=$(yq eval '.features.gatewayAPI.enabled // false' "$profile_file")
}

parse_profile_yq_python() {
    local profile_file="$1"
    
    # Python yq uses different syntax
    export CLUSTER_K8S_VERSION=$(yq -r '.cluster.k8sVersion // "1.32.0"' "$profile_file" 2>/dev/null || echo "1.32.0")
    export CLUSTER_CONTROL_PLANES=$(yq -r '.cluster.controlPlanes // 1' "$profile_file" 2>/dev/null || echo "1")
    export CLUSTER_WORKERS=$(yq -r '.cluster.workers // 2' "$profile_file" 2>/dev/null || echo "2")
    export CLUSTER_DISABLE_CNI=$(yq -r '.cluster.disableCNI // false' "$profile_file" 2>/dev/null || echo "false")
    export CLUSTER_DISABLE_KUBE_PROXY=$(yq -r '.cluster.disableKubeProxy // false' "$profile_file" 2>/dev/null || echo "false")
    
    # Features
    export FEATURE_CILIUM=$(yq -r '.features.cilium.enabled // false' "$profile_file" 2>/dev/null || echo "false")
    export FEATURE_GATEWAY_API=$(yq -r '.features.gatewayAPI.enabled // false' "$profile_file" 2>/dev/null || echo "false")
}

parse_profile_basic() {
    local profile_file="$1"
    
    log_info "Using basic YAML parsing (no yq or unsupported yq version)"
    
    # Parse cluster settings
    export CLUSTER_K8S_VERSION=$(awk '/^cluster:/{flag=1; next} flag && /k8sVersion:/{gsub(/[" ]/, "", $2); print $2; exit}' "$profile_file" 2>/dev/null || echo "1.32.0")
    [ -z "$CLUSTER_K8S_VERSION" ] && export CLUSTER_K8S_VERSION="1.32.0"
    
    export CLUSTER_CONTROL_PLANES=$(awk '/^cluster:/{flag=1; next} flag && /controlPlanes:/{print $2; exit}' "$profile_file" 2>/dev/null || echo "1")
    [ -z "$CLUSTER_CONTROL_PLANES" ] && export CLUSTER_CONTROL_PLANES="1"
    
    export CLUSTER_WORKERS=$(awk '/^cluster:/{flag=1; next} flag && /workers:/{print $2; exit}' "$profile_file" 2>/dev/null || echo "2")
    [ -z "$CLUSTER_WORKERS" ] && export CLUSTER_WORKERS="2"
    
    export CLUSTER_DISABLE_CNI=$(awk '/^cluster:/{flag=1; next} flag && /disableCNI:/{print $2; exit}' "$profile_file" 2>/dev/null || echo "false")
    [ -z "$CLUSTER_DISABLE_CNI" ] && export CLUSTER_DISABLE_CNI="false"
    
    export CLUSTER_DISABLE_KUBE_PROXY=$(awk '/^cluster:/{flag=1; next} flag && /disableKubeProxy:/{print $2; exit}' "$profile_file" 2>/dev/null || echo "false")
    [ -z "$CLUSTER_DISABLE_KUBE_PROXY" ] && export CLUSTER_DISABLE_KUBE_PROXY="false"
    
    # Parse features - much simpler approach
    
    # Simple grep-based parsing
    if grep -A2 "cilium:" "$profile_file" | grep -q "enabled: true"; then
        export FEATURE_CILIUM="true"
    else
        export FEATURE_CILIUM="false"
    fi
    
    if grep -A2 "gatewayAPI:" "$profile_file" | grep -q "enabled: true"; then
        export FEATURE_GATEWAY_API="true"  
    else
        export FEATURE_GATEWAY_API="false"
    fi
    
}

# Generate Kind cluster config
generate_kind_config() {
    local name="$1"
    local config_file="$HOME/.kind-dev/clusters/${name}-config.yaml"
    
    cat > "$config_file" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${name}
nodes:
EOF

    # Add control plane nodes
    for ((i=1; i<=CLUSTER_CONTROL_PLANES; i++)); do
        cat >> "$config_file" << EOF
- role: control-plane
  image: kindest/node:v${CLUSTER_K8S_VERSION}
EOF
        if [ "$i" -eq 1 ]; then
            cat >> "$config_file" << EOF
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
        fi
    done
    
    # Add worker nodes
    for ((i=1; i<=CLUSTER_WORKERS; i++)); do
        cat >> "$config_file" << EOF
- role: worker
  image: kindest/node:v${CLUSTER_K8S_VERSION}
EOF
    done
    
    # Add networking configuration
    if [ "$CLUSTER_DISABLE_CNI" = "true" ] || [ "$CLUSTER_DISABLE_KUBE_PROXY" = "true" ]; then
        cat >> "$config_file" << EOF
networking:
EOF
        [ "$CLUSTER_DISABLE_CNI" = "true" ] && echo "  disableDefaultCNI: true" >> "$config_file"
        [ "$CLUSTER_DISABLE_KUBE_PROXY" = "true" ] && echo "  kubeProxyMode: \"none\"" >> "$config_file"
    fi
    
    echo "$config_file"
}

# Install Gateway API CRDs
install_gateway_api() {
    if [ "$FEATURE_GATEWAY_API" = "true" ]; then
        log_info "Installing Gateway API CRDs..."
        kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
        log_success "Gateway API CRDs installed"
    fi
}

# Install features based on profile
install_features() {
    local name="$1"
    
    # Install Gateway API first if needed
    install_gateway_api
    
    # Install Cilium - the only feature we install directly
    if [ "$FEATURE_CILIUM" = "true" ]; then
        source "$SCRIPT_DIR/features/cilium.sh"
        install_cilium
    fi
    
    log_info "Core cluster features installed. Additional components can be deployed via Flux."
}

# Main function
main() {
    local name="$1"
    
    
    if [ -z "$PROFILE_FILE" ]; then
        log_error "No profile loaded. Use kind-dev create command."
        exit 1
    fi
    
    log_header "Creating Kind cluster: $name"
    log_info "Using profile: $PROFILE_NAME"
    
    # Check dependencies
    check_dependencies
    
    
    # Parse profile
    parse_profile "$PROFILE_FILE"
    
    # Generate and create cluster
    config_file=$(generate_kind_config "$name")
    log_info "Generated config: $config_file"
    
    log_info "Creating cluster..."
    kind create cluster --config "$config_file"
    
    # Wait for cluster
    wait_for_cluster "$name"
    
    # Set context
    kubectl config use-context "kind-$name"
    
    # Install features
    install_features "$name"
    
    # Store cluster metadata
    cat > "$HOME/.kind-dev/clusters/$name.meta" << EOF
profile=$PROFILE_NAME
created=$(date -Iseconds)
cilium=$FEATURE_CILIUM
gatewayAPI=$FEATURE_GATEWAY_API
ready_for_flux=true
EOF
    
    log_success "Cluster '$name' created successfully!"
    log_info "Context: kind-$name"
}

main "$@"