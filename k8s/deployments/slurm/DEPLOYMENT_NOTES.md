# Slurm Deployment Notes - v0.4.1 Setup Journey

## Overview

This document captures the actual deployment process for Slurm on K3s using the Slinky Project v0.4.1, including all issues encountered and their solutions.

## Initial Challenges

### 1. Version Discovery

**Problem:** Initial deployment script referenced v0.2.1, which doesn't exist in the registry.

**Discovery:**
```bash
helm show chart oci://ghcr.io/slinkyproject/charts/slurm-operator-crds
# Revealed actual version: 0.4.1
```

**Solution:** Updated all helm chart references from v0.2.1 to v0.4.1 in:
- `deploy-slurm.sh`
- `values-slurm.yaml`
- `README.md`

### 2. Breaking Schema Changes

**Problem:** The v0.4.1 chart has a completely different schema than v0.2.1.

**Major Changes:**
1. **No built-in MariaDB subchart** - Must deploy separately or disable accounting
2. **Different nodeset structure** - Requires explicit image configuration
3. **Loginset requirements** - Needs sssdConf and service configuration
4. **Partition auto-creation** - Partitions created from nodesets, not manually

## Configuration Issues & Fixes

### Issue 1: Missing Image Repositories

**Error:**
```
Error: execution error at (slurm/templates/nodeset/nodeset-cr.yaml:62:8):
image repository is required
```

**Root Cause:** v0.4.1 requires explicit image configuration for all components.

**Fix:** Added image blocks to all nodesets and loginsets:
```yaml
nodesets:
  debug:
    slurmd:
      image:
        repository: ghcr.io/slinkyproject/slurmd
        tag: 25.05-ubuntu24.04
    logfile:
      image:
        repository: docker.io/library/alpine
        tag: latest

loginsets:
  login:
    login:
      image:
        repository: ghcr.io/slinkyproject/login  # NOT slurmd!
        tag: 25.05-ubuntu24.04
```

**Key Learning:** Login nodes use `ghcr.io/slinkyproject/login`, not `slurmd`!

### Issue 2: Missing sssdConf

**Error:**
```
Error: execution error at (slurm/templates/loginset/loginset-secret.yaml:21:8):
sssdConf is required
```

**Root Cause:** Login nodes require SSSD configuration for user authentication.

**Fix:** Added minimal sssdConf for homelab (no LDAP):
```yaml
loginsets:
  login:
    login:
      sssdConf: |
        [sssd]
        config_file_version = 2
        services = nss,pam
        domains = local

        [nss]
        filter_groups = root,slurm
        filter_users = root,slurm

        [pam]

        [domain/local]
        id_provider = files
```

### Issue 3: Missing Service Configuration

**Error:**
```
Error: template: slurm/templates/NOTES.txt:60:23:
nil pointer evaluating interface {}.port
```

**Root Cause:** Loginset needs service port configuration.

**Fix:** Added service block to loginset:
```yaml
loginsets:
  login:
    service:
      spec:
        type: ClusterIP
      port: 22
```

**Note:** The `spec.type` generates a warning but is accepted.

### Issue 4: Duplicate Partition Configuration

**Error:**
```
fatal: _build_single_partitionline_info: duplicate entry for partition all
```

**Root Cause:** Defined partition "all" in two places:
1. Controller `extraConf`: `PartitionName=all Nodes=ALL ...`
2. `partitions.all` section

**Fix:** Removed manual partition configuration entirely:
```yaml
controller:
  extraConf: null  # Don't manually define partitions

# Removed partitions section - auto-created from nodesets
```

**Key Learning:** In v0.4.1, partitions are automatically created from nodesets. The nodeset configuration creates both the nodes AND the partition.

### Issue 5: Resource Constraints

**Error:**
```
0/6 nodes available: 3 Insufficient cpu, 4 Insufficient memory
```

**Initial Request (per worker):**
- CPU: 2 cores (request), 4 cores (limit)
- Memory: 4Gi (request), 8Gi (limit)

**Cluster Reality:**
- Nodes have ~2GB RAM each with ~70% already used
- Limited CPU capacity with other workloads

**Fix:** Reduced resource requests to realistic values:
```yaml
nodesets:
  debug:
    slurmd:
      resources:
        requests:
          cpu: "500m"      # Down from 2 cores
          memory: "1Gi"    # Down from 4Gi
        limits:
          cpu: "2"         # Down from 4 cores
          memory: "4Gi"    # Down from 8Gi
```

**Key Learning:** Always check actual node resources with `kubectl top nodes` before setting requests.

## Startup Behavior

### Expected Initial Behavior

The controller pod will restart several times (10-15 restarts) during initial setup:
- Container startup probes timeout during initialization
- Configuration is being written and loaded
- Nodes are registering with the controller

**This is normal!** The pod will eventually stabilize at 3/3 Running.

### Node Registration Timing

Worker nodes may take 1-2 minutes to register after controller starts:
1. Controller starts first (shows "No nodes in partition")
2. Workers connect and register
3. Controller reconfigures automatically
4. All nodes show as `idle` in `sinfo`

## Final Working Configuration

### Component Summary

**Deployed Components:**
- slurm-controller-0 (3/3): slurmctld, reconfigure sidecar, logfile sidecar
- slurm-restapi (1/1): REST API on port 8080
- slurm-exporter (1/1): Prometheus metrics exporter
- slurm-login (1/1): SSH-accessible login node
- slurm-worker-slinky-0 (2/2): Default compute node
- slurm-worker-debug-0,1 (2/2 each): Debug partition compute nodes

**Storage:**
- Controller: 4Gi PVC on `local-path` for state persistence
- Workers: No persistent storage (stateless)

**Partitions:**
- `slinky` (1 node): Auto-created from slinky nodeset
- `debug` (2 nodes): Auto-created from debug nodeset
- `all*` (3 nodes): Default partition with all nodes

### What We Disabled

**Accounting (slurmdbd):**
```yaml
accounting:
  enabled: false
```

**Reason:** Would require:
1. Separate MariaDB deployment
2. Database credentials in secrets
3. Additional resource allocation

Can be enabled later if job accounting/history is needed.

## Troubleshooting Commands

### Check Pod Status
```bash
kubectl -n slurm get pods
kubectl -n slurm describe pod <pod-name>
```

### Check Operator Logs
```bash
kubectl -n slinky logs -l app.kubernetes.io/name=slurm-operator
```

### Check Controller Issues
```bash
# Controller logs
kubectl -n slurm logs slurm-controller-0 -c slurmctld --tail=50

# Configuration errors
kubectl -n slurm logs slurm-controller-0 -c logfile | grep -i error
```

### Check Worker Registration
```bash
# From login node
kubectl -n slurm exec -it <login-pod> -- sinfo

# Worker logs
kubectl -n slurm logs <worker-pod> -c slurmd --tail=50
```

### Check Custom Resources
```bash
kubectl -n slurm get controllers,nodesets,loginsets,restapis
kubectl -n slurm describe nodeset <nodeset-name>
```

## Clean Reinstall Procedure

If deployment fails, clean reinstall:

```bash
# 1. Uninstall everything
helm uninstall slurm -n slurm
helm uninstall slurm-operator -n slinky
helm uninstall slurm-operator-crds

# 2. Clean up PVCs (forces fresh state)
kubectl -n slurm delete pvc --all

# 3. Verify namespaces are clean
kubectl -n slurm get all
kubectl -n slinky get all

# 4. Redeploy
cd k8s/deployments/slurm
./deploy-slurm.sh
```

**Note:** Kept secrets (slurm-auth-*) are intentionally preserved for consistency.

## Key Takeaways

1. **Version matters:** Always verify the actual chart version in the registry
2. **Schema changes:** Major version bumps may have breaking changes
3. **Read the defaults:** `helm show values` is essential for understanding required fields
4. **Resource planning:** Check actual node capacity before setting requests
5. **Patience:** Initial startup takes time; multiple restarts are normal
6. **Partition automation:** In v0.4.1, nodesets create partitions automatically
7. **Image specificity:** Different components need different images (login vs slurmd)

## Testing Verification

### Cluster Info
```bash
kubectl -n slurm exec -it <login-pod> -- sinfo
# Should show all partitions with nodes in 'idle' state
```

### Simple Job
```bash
kubectl -n slurm exec <login-pod> -- srun hostname
# Should return a worker hostname
```

### Multi-Node Job
```bash
kubectl -n slurm exec <login-pod> -- srun -N2 -p debug hostname
# Should return two different hostnames
```

### Job Queue
```bash
kubectl -n slurm exec <login-pod> -- squeue
# Should show empty queue or running jobs
```

## Future Enhancements

### Add Accounting Database

1. Deploy MariaDB:
```bash
helm install mariadb bitnami/mariadb \
  --namespace slurm \
  --set auth.rootPassword=changeme \
  --set auth.database=slurm_acct_db \
  --set auth.username=slurm \
  --set auth.password=changeme \
  --set primary.persistence.storageClass=local-path \
  --set primary.persistence.size=5Gi
```

2. Create password secret:
```bash
kubectl -n slurm create secret generic mariadb-password \
  --from-literal=password=changeme
```

3. Enable in values-slurm.yaml:
```yaml
accounting:
  enabled: true
  storageConfig:
    host: mariadb
    port: 3306
    database: slurm_acct_db
    username: slurm
    passwordKeyRef:
      name: mariadb-password
      key: password
```

4. Upgrade:
```bash
helm upgrade slurm oci://ghcr.io/slinkyproject/charts/slurm \
  --values=values-slurm.yaml \
  --version=0.4.1 \
  --namespace=slurm
```

### Add Shared Storage

For jobs that need shared files across nodes:

1. Create CephFS PVC (if available)
2. Add to nodesets and loginsets:
```yaml
nodesets:
  debug:
    slurmd:
      volumeMounts:
        - name: shared-home
          mountPath: /home
    podSpec:
      volumes:
        - name: shared-home
          persistentVolumeClaim:
            claimName: slurm-shared-home
```

### Expose Login Node

For external SSH access:

```yaml
loginsets:
  login:
    service:
      spec:
        type: LoadBalancer  # or NodePort
      port: 22
```

Then access via:
```bash
ssh root@<loadbalancer-ip>
```

## References

- [Slinky Project Documentation](https://slinky.schedmd.com/)
- [Slurm Documentation](https://slurm.schedmd.com/documentation.html)
- [Slinky GitHub](https://github.com/SlinkyProject/slurm-operator)
- [Helm Chart Values](https://github.com/SlinkyProject/slurm-operator/tree/main/helm)

## Deployment Timeline

- Initial attempt: Failed on v0.2.1 (version not found)
- Version discovery: Found v0.4.1
- Configuration iterations: 6 attempts
- Issues resolved: 5 major configuration problems
- Final success: ~15 minutes from clean start with correct config
- Total time (including troubleshooting): ~45 minutes

**Status:** ✅ Production-ready for homelab HPC workloads
