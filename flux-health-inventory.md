# Flux Kustomizations Health Check Inventory

## Current Status
**Total Kustomizations**: 24  
**With Health Checks**: 0  
**Without Health Checks**: 24  

## Kustomizations Requiring Health Checks

### Infrastructure Components (Priority 1)
These are critical infrastructure components that should have health checks:

| Kustomization | Type | Current Status | Recommended Health Checks |
|--------------|------|----------------|---------------------------|
| infra-namespaces | Infrastructure | No health checks | Not needed (just creates namespaces) |
| infra-cilium | CNI | No health checks | DaemonSet/cilium, Deployment/cilium-operator |
| infra-flux-system | GitOps | No health checks | Deployment/\*/flux-system |
| infra-gateways | Gateway API | No health checks | Gateway/\*/infra |
| infra-https-routes | Routes | No health checks | HTTPRoute/\*/infra |
| infra-certmgr-deploy | Cert Manager | No health checks | Deployment/\*/cert-manager |
| infra-certmgr-issuer | Issuer | No health checks | ClusterIssuer/letsencrypt-prod |
| infra-certwildcard | Certificate | No health checks | Certificate/\*/infra |
| falco | Security | No health checks | DaemonSet/falco/falco |
| openebs | Storage | No health checks | DaemonSet/\*/openebs |
| rook-ceph | Storage | No health checks | Deployment/rook-ceph-operator/rook-ceph |
| rook-ceph-details | Storage Config | No health checks | CephCluster/rook-ceph/rook-ceph |
| infra-storage-pvcs | PVCs | No health checks | Not needed (just creates PVCs) |
| kube-node-patches | Node Config | No health checks | Not needed (patches only) |
| infra-app-templates | Templates | No health checks | Not needed (templates only) |

### Applications (Priority 2)
Application deployments that should have health checks:

| Kustomization | Type | Current Status | Recommended Health Checks |
|--------------|------|----------------|---------------------------|
| cnpg-system | Database Operator | No health checks | Deployment/cnpg-controller-manager/cnpg-system |
| n8n | Automation | No health checks | Deployment/n8n/n8n |
| qdrant | Vector DB | No health checks | StatefulSet/qdrant/qdrant |
| pgadmin | Database UI | No health checks | Deployment/pgadmin/pgadmin |
| dashy | Dashboard | No health checks | Deployment/dashy/dashy |
| open-webui | AI UI | No health checks | Deployment/open-webui/open-webui |
| prom-stack | Monitoring | No health checks | Deployment/\*/prom-stack, StatefulSet/\*/prom-stack |
| signoz | Observability | No health checks | Deployment/\*/signoz |
| minio | Object Storage | No health checks | StatefulSet/minio/minio (if still exists) |

## Recommended Health Check Configuration

### For Critical Infrastructure (e.g., Cilium, Cert-Manager)
```yaml
spec:
  interval: 10m
  timeout: 5m
  retryInterval: 2m
  wait: true
  healthChecks:
    - apiVersion: apps/v1
      kind: DaemonSet
      name: cilium
      namespace: kube-system
    - apiVersion: apps/v1
      kind: Deployment
      name: cilium-operator
      namespace: kube-system
```

### For Applications (e.g., n8n, pgadmin)
```yaml
spec:
  interval: 10m
  timeout: 3m
  retryInterval: 1m
  wait: false
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: app-name
      namespace: app-namespace
```

### For StatefulSets (e.g., Qdrant, Prometheus)
```yaml
spec:
  interval: 10m
  timeout: 5m
  retryInterval: 2m
  wait: true
  healthChecks:
    - apiVersion: apps/v1
      kind: StatefulSet
      name: statefulset-name
      namespace: namespace
```

## Implementation Priority

### Phase 1 - Critical Infrastructure (Week 1)
1. infra-cilium - CNI is critical
2. infra-certmgr-deploy - TLS certificates
3. rook-ceph - Primary storage
4. openebs - Secondary storage
5. falco - Security monitoring

### Phase 2 - Core Services (Week 1-2)
1. infra-flux-system - GitOps engine
2. prom-stack - Monitoring
3. cnpg-system - Database operator
4. infra-gateways - Ingress

### Phase 3 - Applications (Week 2)
1. qdrant - Vector database (StatefulSet)
2. open-webui - Main UI
3. n8n - Automation
4. pgadmin - Database management
5. dashy - Dashboard

## Notes
- Not all Kustomizations need health checks (namespaces, patches, templates)
- Use `wait: true` for critical infrastructure
- Use `wait: false` for non-critical applications to prevent blocking
- Adjust timeout based on typical startup time
- Consider dependencies when setting retry intervals