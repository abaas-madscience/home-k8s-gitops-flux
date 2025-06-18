# Make executable
chmod +x kind-cluster-builder.sh kind-cluster-manager.sh

# Create basic cluster
./kind-cluster-builder.sh --name test

# Advanced cluster with Cilium and storage
./kind-cluster-builder.sh --name advanced --disable-cni --cilium --longhorn --ingress

# Create templates and custom charts
./kind-cluster-builder.sh --create-templates

# List available features
./kind-cluster-builder.sh --list-features

# Manage clusters
./kind-cluster-manager.sh list
./kind-cluster-manager.sh switch test
./kind-cluster-manager.sh delete test