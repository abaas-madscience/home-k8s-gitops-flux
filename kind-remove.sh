#!/bin/bash

# This script provides a comprehensive cleanup for a Kind Kubernetes cluster.
# It attempts to delete the cluster using `kind delete cluster`,
# and if any components persist, it forcefully removes:
# 1. Docker containers associated with the cluster.
# 2. The kubeconfig context for the cluster.
# 3. The Docker network created for the cluster.

# --- Configuration ---
# Set -e to exit immediately if a command exits with a non-zero status.
set -e
# Set -u to treat unset variables as an error.
set -u

# --- Functions ---

# Function to display messages
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
    exit 1
}

# Function to check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 could not be found. Please install it to use this script."
    fi
}

# --- Main Script ---

# Check if a cluster name is provided
if [ -z "$1" ]; then
    log_error "Usage: $0 <cluster-name>"
fi

CLUSTER_NAME="$1"
KUBECONFIG_CONTEXT_NAME="kind-$CLUSTER_NAME" # Kind's default context naming convention
KIND_NETWORK_NAME="kind" # The default network name used by Kind

log_info "Starting cleanup process for Kind cluster: '$CLUSTER_NAME'"

# 1. Check for required tools
check_command "kind"
check_command "docker"
check_command "kubectl"

# 2. Attempt standard kind delete
log_info "Attempting to delete cluster '$CLUSTER_NAME' using 'kind delete cluster'..."
if kind delete cluster --name "$CLUSTER_NAME"; then
    log_success "Standard 'kind delete cluster --name $CLUSTER_NAME' command completed successfully."
else
    log_warning "Standard 'kind delete cluster' command failed or had issues. Proceeding with manual cleanup."
fi

# 3. Forcefully remove Docker containers
log_info "Checking for and removing any lingering Docker containers for '$CLUSTER_NAME'..."
# Find all containers whose names start with 'kind-<CLUSTER_NAME>-'
LINGERING_CONTAINERS=$(docker ps -a --format "{{.ID}} {{.Names}}" | grep "^.* kind-${CLUSTER_NAME}-" | awk '{print $1}')

if [ -n "$LINGERING_CONTAINERS" ]; then
    log_info "Found lingering containers. Stopping and removing them..."
    echo "$LINGERING_CONTAINERS" | while read -r CONTAINER_ID; do
        CONTAINER_NAME=$(docker ps -a --filter "id=${CONTAINER_ID}" --format "{{.Names}}")
        log_info "  - Force removing container: $CONTAINER_NAME ($CONTAINER_ID)"
        docker rm -f "$CONTAINER_ID" || log_warning "Failed to remove container $CONTAINER_NAME. It might already be gone."
    done
    log_success "Lingering Docker containers removed (or were already gone)."
else
    log_info "No lingering Docker containers found for '$CLUSTER_NAME'."
fi

# 4. Remove the kubeconfig context
log_info "Checking for and removing kubeconfig context '$KUBECONFIG_CONTEXT_NAME'..."
# Check if the context exists before trying to delete it
if kubectl config get-contexts -o name | grep -q "^$KUBECONFIG_CONTEXT_NAME$"; then
    log_info "Context '$KUBECONFIG_CONTEXT_NAME' found. Deleting it..."
    kubectl config delete-context "$KUBECONFIG_CONTEXT_NAME" || log_warning "Failed to delete kubeconfig context. It might be in use or already gone."
    log_success "Kubeconfig context '$KUBECONFIG_CONTEXT_NAME' removed (or was already gone)."
else
    log_info "Kubeconfig context '$KUBECONFIG_CONTEXT_NAME' not found."
fi

# 5. Remove the Kind-specific Docker network
log_info "Checking for and removing Kind Docker network for '$CLUSTER_NAME'..."
# The network name for a kind cluster is typically "kind" unless it's a very old version or custom config
# For simplicity and common use-cases, we assume 'kind' as the network name if not specified otherwise in custom kind config
# If your kind setup uses a different network name, you'd need to adjust this.

if docker network ls --format "{{.Name}}" | grep -q "^${KIND_NETWORK_NAME}$"; then
    log_info "Docker network '$KIND_NETWORK_NAME' found. Attempting to remove it..."
    # Ensure no containers are using this network (they shouldn't be if previous steps worked)
    if docker network inspect "$KIND_NETWORK_NAME" --format "{{.Containers}}" | grep -q "{}" || [ "$(docker network inspect "$KIND_NETWORK_NAME" --format "{{.Containers}}")" == "map[]" ]; then
        docker network rm "$KIND_NETWORK_NAME" || log_warning "Failed to remove Docker network '$KIND_NETWORK_NAME'. It might be in use by other Kind clusters or already gone."
        log_success "Docker network '$KIND_NETWORK_NAME' removed (or was already gone)."
    else
        log_warning "Docker network '$KIND_NETWORK_NAME' still has active containers. Cannot remove it safely."
        log_warning "Please manually check 'docker network inspect $KIND_NETWORK_NAME' and remove containers if necessary, then run 'docker network rm $KIND_NETWORK_NAME'."
    fi
else
    log_info "Kind Docker network '$KIND_NETWORK_NAME' not found."
fi


log_success "Cleanup process for Kind cluster '$CLUSTER_NAME' completed."
