#!/usr/bin/env bash

# kind-cluster-builder.sh
# A comprehensive tool for creating customizable Kind clusters with various features

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_NAME="test-cluster"
DEFAULT_CONTROL_PLANES=1
DEFAULT_WORKERS=2
DEFAULT_K8S_VERSION="1.32.0"

# Configuration directory
CONFIG_DIR="$HOME/.kind-builder"
FEATURES_DIR="$CONFIG_DIR/features"
CHARTS_DIR="$CONFIG_DIR/charts"

# Initialize directories
mkdir -p "$CONFIG_DIR" "$FEATURES_DIR" "$CHARTS_DIR"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}[BUILDER]${NC} $1"; }

# Check if required tools are installed
check_dependencies() {
    local missing_tools=()
    
    command -v kind >/dev/null 2>&1 || missing_tools+=("kind")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Generate Kind cluster configuration
generate_kind_config() {
    local name="$1"
    local control_planes="$2"
    local workers="$3"
    local k8s_version="$4"
    local disable_cni="$5"
    local disable_kube_proxy="$6"
    
    local config_file="$CONFIG_DIR/${name}-config.yaml"
    
    cat > "$config_file" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${name}
nodes:
EOF

    # Add control plane nodes
    for ((i=1; i<=control_planes; i++)); do
        cat >> "$config_file" << EOF
- role: control-plane
  image: kindest/node:${k8s_version}
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
    for ((i=1; i<=workers; i++)); do
        cat >> "$config_file" << EOF
- role: worker
  image: kindest/node:${k8s_version}
EOF
    done
    
    # Add networking configuration
    if [ "$disable_cni" = "true" ] || [ "$disable_kube_proxy" = "true" ]; then
        cat >> "$config_file" << EOF
networking:
EOF
        [ "$disable_cni" = "true" ] && echo "  disableDefaultCNI: true" >> "$config_file"
        [ "$disable_kube_proxy" = "true" ] && echo "  kubeProxyMode: \"none\"" >> "$config_file"
    fi
    
    echo "$config_file"
}

# Feature installation functions
install_cilium() {
    log_info "Installing Cilium CNI..."
    helm repo add cilium https://helm.cilium.io/ --force-update
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
    kubectl wait --for=condition=ready pod -l k8s-app=cilium --namespace=kube-system --timeout=300s
    log_success "Cilium installed successfully"
}

install_openebs() {
    log_info "Installing OpenEBS storage..."
    helm repo add openebs https://openebs.github.io/charts --force-update
    helm install openebs openebs/openebs --namespace openebs --create-namespace \
        --set legacy.enabled=false \
        --set localprovisioner.enabled=true \
        --set localprovisioner.basePath="/var/openebs/local"
    
    kubectl wait --for=condition=ready pod -l app=openebs-localpv-provisioner --namespace=openebs --timeout=300s
    log_success "OpenEBS installed successfully"
}

install_longhorn() {
    log_info "Installing Longhorn storage..."
    helm repo add longhorn https://charts.longhorn.io --force-update
    helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
    
    kubectl wait --for=condition=ready pod -l app=longhorn-manager --namespace=longhorn-system --timeout=600s
    log_success "Longhorn installed successfully"
}

install_prom_stack() {
    log_info "Installing Prometheus monitoring stack..."
    
    # Add Prometheus community Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install kube-prometheus-stack with Kind-optimized settings
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.retention=24h \
        --set prometheus.prometheusSpec.retentionSize=10GB \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=standard \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
        --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=standard \
        --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=5Gi \
        --set grafana.adminPassword=admin123 \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.storageClassName=standard \
        --set grafana.persistence.size=10Gi \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30080 \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=30090 \
        --set alertmanager.service.type=NodePort \
        --set alertmanager.service.nodePort=30093 \
        --set grafana.grafana\\.ini.server.root_url=http://localhost:30080 \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".apiVersion=1 \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].name=default \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].orgId=1 \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].folder="" \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].type=file \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].disableDeletion=false \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].editable=true \
        --set grafana.dashboardProviders."dashboardproviders\\.yaml".providers[0].options.path=/var/lib/grafana/dashboards/default \
        --timeout 600s
    
    log_info "Waiting for Prometheus stack to be ready..."
    
    # Wait for Prometheus operator
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus-operator --namespace=monitoring --timeout=300s
    
    # Wait for Prometheus server
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace=monitoring --timeout=300s
    
    # Wait for Grafana
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace=monitoring --timeout=300s
    
    # Wait for AlertManager
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=alertmanager --namespace=monitoring --timeout=300s
    
    log_success "Prometheus monitoring stack installed successfully!"
    log_info "Access URLs (using kubectl port-forward or NodePort):"
    log_info "  Grafana:      http://localhost:30080 (admin/admin123)"
    log_info "  Prometheus:   http://localhost:30090"
    log_info "  AlertManager: http://localhost:30093"
    log_info ""
    log_info "Port-forward commands (alternative to NodePort):"
    log_info "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    log_info "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    log_info "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093"
}

install_prom_stack_with_storage_monitoring() {
    log_info "Installing Prometheus stack with enhanced storage monitoring..."
    
    # Add repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Create custom values file for storage monitoring
    cat > "$CONFIG_DIR/prometheus-values.yaml" << 'EOF'
prometheus:
  prometheusSpec:
    retention: 24h
    retentionSize: 10GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          resources:
            requests:
              storage: 20Gi
    additionalScrapeConfigs:
      - job_name: 'kubernetes-storage-metrics'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          resources:
            requests:
              storage: 5Gi

grafana:
  adminPassword: admin123
  persistence:
    enabled: true
    storageClassName: standard
    size: 10Gi
  service:
    type: NodePort
    nodePort: 30080
  grafana.ini:
    server:
      root_url: http://localhost:30080
  dashboardsConfigMaps:
    - configMapName: storage-dashboards
      fileName: storage-performance.json
  additionalDataSources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-kube-prometheus-prometheus:9090
      access: proxy
      isDefault: true

nodeExporter:
  enabled: true
  
kubeStateMetrics:
  enabled: true

defaultRules:
  create: true
  rules:
    storage: true
    volume: true
EOF

    # Install with custom values
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$CONFIG_DIR/prometheus-values.yaml" \
        --timeout 600s
    
    # Create storage performance dashboard
    kubectl create configmap storage-dashboards -n monitoring \
        --from-literal=storage-performance.json="$(cat <<'DASHBOARD'
{
  "dashboard": {
    "id": null,
    "title": "Storage Performance Comparison",
    "tags": ["storage", "performance"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Disk I/O Operations",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_disk_reads_completed_total[5m])",
            "legendFormat": "{{device}} - Reads/sec"
          },
          {
            "expr": "rate(node_disk_writes_completed_total[5m])",
            "legendFormat": "{{device}} - Writes/sec"
          }
        ]
      },
      {
        "title": "Disk Throughput",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_disk_read_bytes_total[5m])",
            "legendFormat": "{{device}} - Read Bytes/sec"
          },
          {
            "expr": "rate(node_disk_written_bytes_total[5m])",
            "legendFormat": "{{device}} - Write Bytes/sec"
          }
        ]
      },
      {
        "title": "PV Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes",
            "legendFormat": "{{persistentvolumeclaim}} Usage %"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
DASHBOARD
)" 2>/dev/null || log_warning "Dashboard creation failed, will be available in Grafana import"

    log_info "Waiting for Prometheus stack to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus-operator --namespace=monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace=monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace=monitoring --timeout=300s
    
    log_success "Prometheus monitoring stack with storage monitoring installed!"
    log_info "Access URLs:"
    log_info "  Grafana:      http://localhost:30080 (admin/admin123)"
    log_info "  Prometheus:   http://localhost:30090"
    log_info ""
    log_info "For storage performance testing, deploy workloads and monitor:"
    log_info "  - Disk I/O operations and throughput"
    log_info "  - PV usage and performance metrics"
    log_info "  - Storage class comparison dashboards"
}

install_ingress_nginx() {
    log_info "Installing NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.hostPort.enabled=true
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller --namespace=ingress-nginx --timeout=300s
    log_success "NGINX Ingress Controller installed successfully"
}

# Install custom Helm charts
install_custom_charts() {
    local charts_list="$1"
    
    if [ -z "$charts_list" ]; then
        return 0
    fi
    
    IFS=',' read -ra CHARTS <<< "$charts_list"
    for chart in "${CHARTS[@]}"; do
        chart=$(echo "$chart" | xargs) # Trim whitespace
        
        if [ -f "$CHARTS_DIR/$chart.yaml" ]; then
            log_info "Installing custom chart: $chart"
            source "$CHARTS_DIR/$chart.yaml"
            log_success "Custom chart $chart installed"
        else
            log_warning "Custom chart file not found: $CHARTS_DIR/$chart.yaml"
        fi
    done
}

# Wait for cluster to be ready
wait_for_cluster() {
    local name="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for cluster '$name' to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl cluster-info --context "kind-$name" >/dev/null 2>&1; then
            if kubectl get nodes --context "kind-$name" | grep -q "Ready"; then
                log_success "Cluster '$name' is ready!"
                return 0
            fi
        fi
        
        log_info "Attempt $attempt/$max_attempts - Cluster not ready yet, waiting..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Cluster failed to become ready within timeout"
    return 1
}

# Create feature templates
create_feature_templates() {
    # Cilium with custom values
    cat > "$FEATURES_DIR/cilium-custom.yaml" << 'EOF'
#!/bin/bash
# Custom Cilium installation
helm repo add cilium https://helm.cilium.io/ --force-update
helm install cilium cilium/cilium --version 1.14.5 \
    --namespace kube-system \
    --set operator.replicas=1 \
    --set tunnel=vxlan \
    --set ipam.mode=kubernetes \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true
EOF
    chmod +x "$FEATURES_DIR/cilium-custom.yaml"
    
    # Example custom chart
    cat > "$CHARTS_DIR/monitoring.yaml" << 'EOF'
#!/bin/bash
# Monitoring stack with Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --set prometheus.prometheusSpec.retention=7d \
    --set grafana.adminPassword=admin123
EOF
    chmod +x "$CHARTS_DIR/monitoring.yaml"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A comprehensive tool for creating customizable Kind clusters

OPTIONS:
    -n, --name NAME                 Cluster name (default: $DEFAULT_NAME)
    -c, --control-planes NUM        Number of control planes (default: $DEFAULT_CONTROL_PLANES)
    -w, --workers NUM               Number of workers (default: $DEFAULT_WORKERS)
    -k, --k8s-version VERSION       Kubernetes version (default: $DEFAULT_K8S_VERSION)
    --disable-cni                   Disable default CNI
    --disable-kube-proxy            Disable kube-proxy
    --cilium                        Install Cilium CNI
    --openebs                       Install OpenEBS storage
    --longhorn                      Install Longhorn storage
    --prometheus|--prometheus       Install Prometheus monitoring stack
    --ingress                       Install NGINX Ingress Controller
    --charts LIST                   Comma-separated list of custom charts to install
    --list-features                 List available features and custom charts
    --create-templates              Create example feature templates
    -h, --help                      Show this help message

EXAMPLES:
    # Basic cluster
    $0 --name my-cluster

    # Cluster with Cilium and storage
    $0 --name test --disable-cni --cilium --openebs

    # Full-featured cluster
    $0 --name full-test --workers 3 --cilium --longhorn --ingress --charts monitoring

    # List available features
    $0 --list-features
EOF
}

# List available features
list_features() {
    log_header "Available Built-in Features:"
    echo "  - cilium: Install Cilium CNI"
    echo "  - openebs: Install OpenEBS storage"
    echo "  - longhorn: Install Longhorn storage"
    echo "  - ingress: Install NGINX Ingress Controller"
    
    echo
    log_header "Available Custom Charts:"
    if [ -d "$CHARTS_DIR" ] && [ "$(ls -A "$CHARTS_DIR" 2>/dev/null)" ]; then
        for chart in "$CHARTS_DIR"/*.yaml; do
            if [ -f "$chart" ]; then
                basename "$chart" .yaml
            fi
        done
    else
        echo "  No custom charts found in $CHARTS_DIR"
    fi
    
    echo
    log_header "Available Feature Templates:"
    if [ -d "$FEATURES_DIR" ] && [ "$(ls -A "$FEATURES_DIR" 2>/dev/null)" ]; then
        for feature in "$FEATURES_DIR"/*.yaml; do
            if [ -f "$feature" ]; then
                basename "$feature" .yaml
            fi
        done
    else
        echo "  No feature templates found in $FEATURES_DIR"
    fi
}

# Main function
main() {
    local name="$DEFAULT_NAME"
    local control_planes="$DEFAULT_CONTROL_PLANES"
    local workers="$DEFAULT_WORKERS"
    local k8s_version="$DEFAULT_K8S_VERSION"
    local disable_cni="false"
    local disable_kube_proxy="false"
    local install_cilium="false"
    local install_openebs="false"
    local install_longhorn="false"
    local install_ingress="false"
    local install_prometheus="false"
    local custom_charts=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -c|--control-planes)
                control_planes="$2"
                shift 2
                ;;
            -w|--workers)
                workers="$2"
                shift 2
                ;;
            -k|--k8s-version)
                k8s_version="$2"
                shift 2
                ;;
            --disable-cni)
                disable_cni="true"
                shift
                ;;
            --disable-kube-proxy)
                disable_kube_proxy="true"
                shift
                ;;
            --cilium)
                install_cilium="true"
                shift
                ;;
            --openebs)
                install_openebs="true"
                shift
                ;;
            --longhorn)
                install_longhorn="true"
                shift
                ;;
            --ingress)
                install_ingress="true"
                shift
                ;;
            --charts)
                custom_charts="$2"
                shift 2
                ;;
            --list-features)
                list_features
                exit 0
                ;;
            --create-templates)
                create_feature_templates
                log_success "Feature templates created in $FEATURES_DIR and $CHARTS_DIR"
                exit 0
                ;;
            --prometheus|--prom)
                install_prometheus="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_header "Kind Cluster Builder Starting..."
    
    # Check dependencies
    check_dependencies
    
    # Generate Kind configuration
    log_info "Generating Kind cluster configuration..."
    config_file=$(generate_kind_config "$name" "$control_planes" "$workers" "$k8s_version" "$disable_cni" "$disable_kube_proxy")
    log_success "Configuration generated: $config_file"
    
    # Create the cluster
    log_info "Creating Kind cluster '$name'..."
    kind create cluster --config "$config_file"
    
    # Wait for cluster to be ready
    wait_for_cluster "$name"
    
    # Set kubectl context
    kubectl config use-context "kind-$name"
    
    # Install features
    if [ "$install_cilium" = "true" ]; then
        install_cilium
    fi
    
    if [ "$install_openebs" = "true" ]; then
        install_openebs
    fi
    
    if [ "$install_longhorn" = "true" ]; then
        install_longhorn
    fi
    
    if [ "$install_ingress" = "true" ]; then
        install_ingress_nginx
    fi
    if [ "$install_prometheus" = "true" ]; then
        install_prom_stack_with_storage_monitoring
    fi

    
    # Install custom charts
    install_custom_charts "$custom_charts"
    
    # Cleanup temporary config
    rm -f "$config_file"
    
    log_success "Cluster '$name' created successfully!"
    log_info "Use 'kubectl config use-context kind-$name' to interact with your cluster"
    log_info "Use 'kind delete cluster --name $name' to delete the cluster when done"
}

# Run main function with all arguments
main "$@"
