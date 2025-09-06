# App Template Implementation Plan

## Current Issues Identified

1. **Mismatched values**: 
   - Template expects `storage` but cool-app uses `storage` (should be consistent)
   - Template has `database` but cool-app references `storage`
   - `ingress.customHost` vs `ingress.host` inconsistency

2. **Missing namespace**:
   - cool-app deploys to `default` namespace (not ideal)
   - Should create dedicated namespace or use existing pattern

3. **No Kustomization**:
   - cool-app HelmRelease isn't deployed via Flux Kustomization
   - Needs proper GitOps integration

4. **Template gaps**:
   - Missing PVC template when storage is enabled
   - Missing ConfigMap/Secret management
   - Service port hardcoded to 80, but app.port is configurable

## Step-by-Step Fix Plan

### Step 1: Fix the app-template Chart
- [ ] Align values.yaml with actual needs
- [ ] Fix deployment.yaml container spec
- [ ] Add PVC template for storage
- [ ] Fix service port mapping
- [ ] Add ConfigMap template for env vars
- [ ] Update HTTPRoute to use correct values

### Step 2: Create Proper App Structure
```
apps/cool-app/
├── kustomization.yaml     # Kustomize file
├── namespace.yaml         # Namespace definition
├── helmrelease.yaml       # HelmRelease
└── values.yaml           # Optional: separate values file
```

### Step 3: Add Flux Kustomization
Create `clusters/lab/apps-cool-app.yaml` to deploy via GitOps

### Step 4: Test with Real App
Deploy a simple app like nginx or httpbin to validate

## Proposed Enhanced Values Structure

```yaml
app:
  name: ""           # Required: app name
  image: ""          # Required: Docker image
  tag: "latest"      # Image tag
  port: 8080         # Container port
  
  # Optional: Command override
  command: []
  args: []

# Deployment settings
replicas: 1
namespace: ""        # If empty, use app.name

# Environment variables
env: {}              # Key-value pairs
envFrom: []          # ConfigMap/Secret references

# Storage
persistence:
  enabled: false
  size: "10Gi"
  mountPath: "/data"
  storageClass: "openebs-hostpath"  # Your default

# Ingress via Gateway API
ingress:
  enabled: false
  hostname: ""       # If empty, use app.name.cluster
  path: "/"
  gateway: "public-gateway"
  gatewayNamespace: "infra-gateway"

# Health checks
health:
  enabled: true
  liveness:
    path: "/healthz"
    initialDelaySeconds: 30
  readiness:
    path: "/ready"
    initialDelaySeconds: 5

# Resources
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"

# Service
service:
  type: ClusterIP
  port: 80          # Service port
  targetPort: ""    # If empty, use app.port

# Monitoring
monitoring:
  enabled: true
  path: "/metrics"
```

## Next Actions

1. First, let's fix the core template files
2. Create a working example with nginx
3. Test deployment through Flux
4. Document usage patterns