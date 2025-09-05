# Kind Development Tools

A comprehensive toolkit for creating and managing Kind (Kubernetes in Docker) clusters for development and testing, with built-in GitOps integration.

## 🚀 Quick Start

```bash
# Create basic development cluster
./kind-dev create

# Create advanced cluster with Cilium
./kind-dev create cilium test-cilium

# Create full GitOps-ready cluster  
./kind-dev create gitops lab

# Bootstrap Flux GitOps
./kind-dev bootstrap lab

# List all clusters
./kind-dev list

# Switch between clusters
./kind-dev switch test-cilium
```

## 📁 Project Structure

```
kind-tools/
├── kind-dev              # Main CLI tool
├── profiles/              # Cluster configuration profiles
│   ├── basic.yaml        # Basic cluster
│   ├── cilium.yaml       # Cilium CNI cluster  
│   ├── gitops.yaml       # Full GitOps cluster
│   └── homelab.yaml      # Homelab simulation
├── scripts/               # Core functionality scripts
│   ├── common.sh         # Shared functions
│   ├── cluster-*.sh      # Cluster management
│   ├── flux-*.sh         # GitOps integration
│   └── features/         # Feature installers
└── templates/             # Configuration templates
```

## 🛠 Available Commands

### Cluster Management
- `create [PROFILE] [NAME]` - Create cluster with profile
- `delete NAME` - Delete cluster  
- `list` - List all clusters with status
- `switch NAME` - Switch kubectl context
- `info [NAME]` - Show cluster details
- `validate [NAME]` - Validate cluster health
- `suspend NAME` - Suspend cluster to save resources
- `resume NAME` - Resume suspended cluster

### GitOps Integration  
- `bootstrap NAME [REPO]` - Bootstrap Flux GitOps
- `profiles` - List available profiles

## 📋 Cluster Profiles

### Basic Profile
Minimal Kind cluster with default settings:
- Default CNI (kindnet)
- 1 control plane, 2 workers
- Ready for basic development

### Cilium Profile  
Advanced networking with Cilium:
- Cilium CNI replacing kube-proxy
- Gateway API CRDs installed
- L2 announcements enabled
- 1 control plane, 2 workers

### GitOps Profile
GitOps-ready cluster:
- Cilium CNI + Gateway API
- 1 control plane, 3 workers
- Rook-Ceph storage ready (mounted storage on each worker)
- Ready for Flux bootstrap
- Additional apps deployed via GitOps

### Homelab Profile
Homelab networking simulation:
- Cilium with Hubble enabled
- Gateway API support
- 3 worker nodes for realistic testing
- Rook-Ceph storage mounts for distributed storage testing
- Matches homelab networking setup

## 🔧 Prerequisites

Install required tools:
```bash
# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Flux CLI (for GitOps)
curl -s https://fluxcd.io/install.sh | sudo bash
```

## 📖 Usage Examples

### Development Workflow

```bash
# Start with basic cluster
./kind-dev create basic dev
./kind-dev info dev

# Test with Cilium networking  
./kind-dev create cilium cilium-test
./kind-dev validate cilium-test

# Full GitOps development
./kind-dev create gitops lab
export GITHUB_TOKEN=your_token_here
./kind-dev bootstrap lab

# Switch between clusters
./kind-dev switch dev
./kind-dev switch cilium-test
./kind-dev list

# Suspend cluster to save battery/resources
./kind-dev suspend lab
# Resume when needed
./kind-dev resume lab

# Clean up
./kind-dev delete dev
./kind-dev delete cilium-test
```

### GitOps Integration

The tool integrates with your existing GitOps repository:

```bash
# Bootstrap with default repository (abaas-madscience/home-k8s-gitops-flux)
./kind-dev bootstrap lab

# Bootstrap with custom repository
./kind-dev bootstrap lab owner/custom-repo

# Uses branch: kind, path: clusters/kind
```

### Custom Profiles

Create your own profile in `profiles/custom.yaml`:

```yaml
# Description: My custom cluster setup
apiVersion: kind-dev/v1alpha1
kind: Profile
metadata:
  name: custom
  description: Custom development cluster

cluster:
  k8sVersion: "1.32.0"
  controlPlanes: 1
  workers: 2
  disableCNI: true

features:
  cilium:
    enabled: true
  openebs:
    enabled: true
  # ... other features
```

Then use it:
```bash
./kind-dev create custom my-cluster
```

## 🔍 Troubleshooting

### Common Issues

**Cluster creation fails:**
```bash
# Check Docker is running
docker ps

# Validate dependencies
./kind-dev create --help

# Check available resources
docker system df
```

**Networking issues:**
```bash
# Validate cluster networking
./kind-dev validate CLUSTER_NAME

# Check Cilium status (if using Cilium profile)
kubectl get pods -n kube-system -l k8s-app=cilium
```

**GitOps bootstrap fails:**
```bash
# Check GitHub token
echo $GITHUB_TOKEN

# Verify repository access
gh repo view owner/repo

# Check Flux prerequisites  
flux check --pre
```

### Health Checks

The tool includes comprehensive validation:

```bash
# Full cluster validation
./kind-dev validate CLUSTER_NAME

# This checks:
# - Node readiness
# - System pods health  
# - Networking (DNS resolution)
# - Storage classes
# - Installed features
# - Basic smoke tests
```

## 🤝 Integration with Homelab

This tool is designed to work alongside your homelab GitOps setup:

- **Repository Structure**: Compatible with existing flux structure
- **Branch Strategy**: Uses `kind` branch for development
- **Path Convention**: `clusters/kind` for kind-specific configs
- **Feature Parity**: Replicates homelab components (Cilium, storage, monitoring)

## 🎯 Advanced Usage

### Profile Customization

Profiles support various features:
- Multiple Kubernetes versions
- Different node configurations
- Feature toggles (CNI, storage, monitoring)
- GitOps settings
- Experimental features

### Script Integration

Individual scripts can be called directly:
```bash
# Direct script usage
./scripts/cluster-create.sh my-cluster
./scripts/flux-bootstrap.sh my-cluster
```

### Configuration Directory

User configuration is stored in `~/.kind-dev/`:
```
~/.kind-dev/
├── clusters/           # Cluster metadata and configs
├── profiles/           # Custom profiles
└── cache/             # Cached resources
```

## 📈 Future Enhancements

Planned improvements:
- [ ] Multi-cluster management
- [ ] Backup/restore functionality  
- [ ] Performance benchmarking
- [ ] Template generation
- [ ] CI/CD integration helpers
- [ ] Cluster upgrade automation

## 🐛 Issues & Contributing

Found a bug or have a suggestion? Please check the existing issues or create a new one.

For development:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with different profiles
5. Submit a pull request

---

**Happy Kubernetes development! 🚢**