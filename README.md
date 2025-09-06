# 🏠 HomeLab Kubernetes GitOps Platform

A comprehensive Kubernetes homelab platform leveraging **Talos Linux**, **Kind**, and **FluxCD** for declarative GitOps-based infrastructure management.

## 🏗️ Architecture Overview

This repository implements a dual-cluster strategy for homelab experimentation and learning:

- **HomeLab**: Talos Linux bare-metal cluster tracking `main` branch
- **Development**: Kind (Kubernetes in Docker) clusters tracking `kind` branch
- **GitOps**: FluxCD for continuous deployment with branch-based environments
- **Promotion**: `tools/migrate.sh` script for promoting changes from Kind to HomeLab

### Current Cluster Status

**HomeLab Cluster (Talos)**
- Control Plane: 3 nodes (HA configuration)
  - CP-02: Ryzen 7 5700U w/ 32GB RAM (heavy workload node)
- Workers: 1 compute node + 1 storage node
- Kubernetes: v1.33.2
- CNI: Cilium (strict kube-proxy replacement)
- Storage: 
  - Rook-Ceph: Distributed storage across cluster
  - OpenEBS: Local hostpath volumes on CP-02 for databases (Qdrant, CNPG)

## 📁 Repository Structure

```
.
├── clusters/
│   ├── lab/                # HomeLab Talos cluster manifests
│   │   ├── flux-system/     # FluxCD bootstrap configuration
│   │   └── *.yaml          # Kustomization definitions
│   └── kind/               # Development Kind cluster manifests
├── infrastructure/         # Core platform components
│   ├── cilium/            # CNI and networking
│   ├── cert-manager/      # TLS certificate management
│   ├── rook-ceph/         # Distributed storage
│   ├── falco/             # Runtime security
│   ├── gateways/          # Gateway API configuration
│   └── https-routes/      # HTTP routing rules
├── apps/                   # Application deployments
│   ├── cnpg-system/       # CloudNative PostgreSQL
│   ├── prom-stack/        # Prometheus monitoring
│   ├── open-webui/        # AI/LLM interface
│   ├── qdrant/            # Vector database
│   └── ...                # Additional applications
├── kind-tools/            # Kind development toolkit
│   ├── kind-dev           # CLI for Kind cluster management
│   ├── profiles/          # Cluster configuration profiles
│   └── scripts/           # Automation scripts
└── docs/                  # Documentation and helpers
```

## 🛠️ Technology Stack

### Core Infrastructure
- **Kubernetes Distribution**: Talos Linux (immutable, API-driven OS)
- **Container Runtime**: containerd
- **Networking**: Cilium with eBPF (replacing kube-proxy)
- **Service Mesh**: Cilium service mesh capabilities
- **Storage**: 
  - Rook-Ceph: Distributed storage with CephFS, RBD, and RGW (S3-compatible object storage)
  - OpenEBS: Local hostpath volumes for database workloads
- **Ingress**: Gateway API with Cilium implementation

### GitOps & Automation
- **GitOps Engine**: FluxCD v2
- **Source Control**: Git repository as single source of truth
- **Deployment Strategy**: Kustomizations with automatic reconciliation
- **Secrets Management**: Sealed Secrets / SOPS (planned)

### Security & Observability
- **Runtime Security**: Falco with custom rules
- **Certificate Management**: cert-manager with Let's Encrypt
- **Monitoring**: Prometheus Stack (Prometheus, Grafana, AlertManager)
- **Logging**: SignOz (planned)
- **Cost Management**: OpenCost

### Applications
- **Databases**: CloudNative PostgreSQL (CNPG), pgAdmin
- **AI/ML**: Open WebUI, Ollama, Qdrant vector database
- **Object Storage**: Rook-Ceph RGW (S3-compatible)
- **Automation**: n8n workflow automation
- **Dashboard**: Dashy

## 🚀 Quick Start

### Prerequisites

- Docker (for Kind development)
- kubectl
- Flux CLI
- Talos CLI (talosctl) for HomeLab cluster

### Development Environment (Kind)

```bash
# Navigate to Kind tools
cd kind-tools/

# Create a GitOps-ready development cluster
./kind-dev create gitops dev-cluster

# Bootstrap Flux to track 'kind' branch (requires GITHUB_TOKEN)
export GITHUB_TOKEN=your_token_here
./kind-dev bootstrap dev-cluster

# Validate cluster health
./kind-dev validate dev-cluster

# Development workflow uses 'kind' branch
git checkout kind
# Make changes, test in Kind cluster
# Use ./tools/migrate.sh to promote to HomeLab
```

### HomeLab Environment (Talos)

```bash
# Check cluster status
kubectl get nodes
kubectl get kustomizations -A

# Force reconciliation
flux reconcile source git flux-system --with-source
flux reconcile kustomization flux-system --with-source

# Validate configurations
./pre-commit.sh  # Validate HTTPRoute configurations
./validate.sh    # Check resource crosslinks
```

## 📋 Key Features

### Multi-Environment Support
- **HomeLab**: Bare-metal Talos cluster for learning and experimentation
- **Development**: Ephemeral Kind clusters for testing
- **GitOps**: Unified deployment model across environments

### Advanced Networking
- **Cilium CNI**: eBPF-based networking and security
- **Gateway API**: Modern ingress management
- **L2 Announcements**: Direct service exposure
- **Network Policies**: Microsegmentation and zero-trust networking

### Storage Solutions
- **Rook-Ceph**: Distributed block, file, and object storage across cluster nodes
- **OpenEBS**: Local hostpath volumes on CP-02 for high-performance database workloads
  - Qdrant vector database leveraging CP-02's 32GB RAM
  - CNPG PostgreSQL instances with dedicated resources
- **Backup Strategy**: Scheduled backups with retention policies

### Security Hardening
- **Immutable OS**: Talos Linux reduces attack surface
- **Runtime Protection**: Falco monitors suspicious activities
- **Network Policies**: Default-deny with explicit allows
- **TLS Everywhere**: Automated certificate management

## 🔧 Common Operations

### Flux Management
```bash
# Check reconciliation status
flux get all

# Force sync specific kustomization
flux reconcile ks <name> -n flux-system --with-source

# Suspend/Resume deployments
flux suspend ks <name> -n flux-system
flux resume ks <name> -n flux-system
```

### Troubleshooting
```bash
# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Review Flux logs
flux logs --tail 50

# Validate manifests
kubectl apply --dry-run=client -f <manifest>

# Clean up failed resources
./scripts/orphan.sh  # Find orphaned resources
```

### Development Workflow
```bash
# Switch to kind branch for development
git checkout kind

# Make changes to manifests
vi apps/myapp/deployment.yaml

# Validate changes locally
./pre-commit.sh

# Commit and push to kind branch
git add .
git commit -m "Update myapp deployment"
git push

# Reconcile on Kind cluster
flux reconcile source git flux-system --with-source
flux reconcile ks <app-name> -n flux-system --with-source

# Validate in Kind environment
kubectl get pods -n myapp --watch
kubectl logs -n myapp -f deployment/myapp

# Once validated, migrate to HomeLab
./tools/migrate.sh

# Verify HomeLab deployment
git checkout main
kubectl get pods -n myapp --watch
flux get ks --watch
```

## 📈 Roadmap

### In Progress
- [x] Talos cluster migration
- [x] Rook-Ceph distributed storage
- [x] Gateway API implementation
- [ ] SOPS secret encryption

### Planned Enhancements
- [ ] Multi-cluster mesh with Cilium
- [ ] Automated backup/restore pipelines
- [ ] Progressive delivery with Flagger
- [ ] Cost optimization with Karpenter
- [ ] Enhanced observability stack
- [ ] Disaster recovery procedures

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes in Kind cluster
4. Run validation scripts
5. Submit pull request

## 📚 Documentation

- [docs/FLUXHELPER.md](docs/FLUXHELPER.md) - Flux troubleshooting guide
- [kind-tools/README.md](kind-tools/README.md) - Kind development toolkit

## 🔒 Security

- No secrets in Git (use Sealed Secrets/SOPS)
- Network policies enforce microsegmentation
- Regular security updates via Flux
- Runtime monitoring with Falco

## 📝 License

This project is designed for homelab experimentation and learning. Not intended for production use without additional security hardening and testing.

---

**Status**: HomeLab Active | **Platform**: Talos + Kind | **GitOps**: FluxCD v2