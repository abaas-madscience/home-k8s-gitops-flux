# Migration Guide

## From Old Scripts to kind-dev

Your existing scripts have been reorganized into a unified tool. Here's the migration path:

### Old vs New Commands

| Old Command | New Command | Notes |
|------------|-------------|--------|
| `./cluster-builder.sh --name test` | `./kind-dev create basic test` | Basic cluster |
| `./advanced.sh` | `./kind-dev create cilium advanced` | Cilium cluster |
| `./cluster-builder.sh --cilium --longhorn` | `./kind-dev create gitops dev` | Full-featured |
| `./cluster-manager.sh list` | `./kind-dev list` | List clusters |
| `./cluster-manager.sh switch NAME` | `./kind-dev switch NAME` | Switch context |
| `./cluster-manager.sh delete NAME` | `./kind-dev delete NAME` | Delete cluster |
| `./flux-boot.sh` | `./kind-dev bootstrap NAME` | Bootstrap GitOps |

### What's Improved

1. **Unified Interface**: Single `kind-dev` command instead of multiple scripts
2. **Profile System**: Predefined configurations instead of long command lines
3. **Better Validation**: Comprehensive health checks and validation
4. **Metadata Tracking**: Cluster creation time, profile used, features installed
5. **GitOps Integration**: Improved Flux bootstrap with proper repository handling
6. **Error Handling**: Better error messages and recovery suggestions

### Migration Steps

1. **Test the new tool** (your existing clusters remain untouched):
   ```bash
   ./kind-dev profiles
   ./kind-dev list
   ```

2. **Create a test cluster** with the new system:
   ```bash
   ./kind-dev create cilium test-new
   ./kind-dev info test-new
   ./kind-dev validate test-new
   ```

3. **Compare with old method**:
   ```bash
   # Old way
   ./cluster-builder.sh --name test-old --disable-cni --cilium
   
   # New way  
   ./kind-dev create cilium test-new
   ```

4. **Clean up old clusters** when satisfied:
   ```bash
   ./kind-dev delete test-new
   kind delete cluster --name test-old
   ```

### Backwards Compatibility

Your old scripts still work, but the new system offers:
- Better error handling
- Consistent logging
- Metadata tracking
- Health validation
- Profile management

### Custom Profiles

If you had custom configurations in the old scripts, create custom profiles:

```yaml
# profiles/my-custom.yaml
apiVersion: kind-dev/v1alpha1
kind: Profile
metadata:
  name: my-custom
  description: My custom cluster configuration

cluster:
  k8sVersion: "1.32.0"
  controlPlanes: 1
  workers: 3
  disableCNI: true

features:
  cilium:
    enabled: true
  longhorn:
    enabled: true
  prometheus:
    enabled: true
```

Then use: `./kind-dev create my-custom cluster-name`

### File Cleanup

After migration, you can optionally move old files:

```bash
# Archive old scripts
mkdir -p archive
mv cluster-builder.sh archive/
mv advanced.sh archive/
mv cluster-manager.sh archive/
mv flux-boot.sh archive/

# Keep the new system
# kind-dev (main tool)
# profiles/ (configurations)
# scripts/ (modular scripts)
# README.md (documentation)
```