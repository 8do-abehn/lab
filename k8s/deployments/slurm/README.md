# Slurm on Kubernetes - Slinky Project

Deploy a complete Slurm HPC cluster on your K3s homelab using the [Slinky Project](https://github.com/SlinkyProject/slurm-operator) from SchedMD.

## Overview

This deployment uses Slinky to run Slurm workload manager entirely within Kubernetes, enabling HPC-style batch job scheduling alongside your containerized workloads.

**Components deployed:**
- **slurm-operator**: Manages Slurm cluster lifecycle in Kubernetes
- **slurmctld**: Slurm controller daemon
- **slurmd**: Compute node daemons (configurable replicas)
- **slurmdbd**: Slurm database daemon (accounting)
- **MariaDB**: Accounting database
- **REST API**: Remote job submission endpoint
- **Login node**: Interactive access point
- **Prometheus exporter**: Metrics for monitoring

## Architecture

```
┌─────────────────────────────────────────────────┐
│        K3s Cluster (1 master + 6 workers)       │
│                                                 │
│  ┌──────────────┐  ┌─────────────────────────┐ │
│  │   slinky     │  │        slurm            │ │
│  │  namespace   │  │      namespace          │ │
│  │              │  │                         │ │
│  │  Operator    │──▶  slurmctld (controller) │ │
│  │              │  │  slurmd (compute x2)    │ │
│  │              │  │  login node             │ │
│  │              │  │  REST API               │ │
│  │              │  │  Prometheus exporter    │ │
│  └──────────────┘  └─────────────────────────┘ │
│                                                 │
│  Storage:                                       │
│  - local-path: Controller state (4Gi)          │
│  - CephFS: NOT configured (optional)           │
│                                                 │
│  Note: Accounting (slurmdbd/MariaDB) disabled  │
└─────────────────────────────────────────────────┘
```

## Prerequisites

- K3s/K8s cluster with at least 3 worker nodes
- Helm 3.x installed
- kubectl configured to access your cluster
- Storage class:
  - `local-path` for controller state (ReadWriteOnce) - **Required**
  - `cephfs` for shared storage (ReadWriteMany) - **Optional, not configured**

**Resource requirements:**
- Minimum: 8 CPU cores, 16GB RAM across cluster
- Recommended: 12+ CPU cores, 24GB+ RAM for production workloads

**Current deployment:**
- Uses only `local-path` storage for controller state (4Gi)
- No shared filesystem between compute nodes
- Suitable for testing and learning Slurm
- See "Storage" section below for adding CephFS if needed

## Quick Start

### 1. Deploy with automated script

```bash
cd k8s/deployments/slurm/
./deploy-slurm.sh
```

This script will:
1. Add required Helm repositories
2. Install cert-manager (for TLS certificates)
3. Install Prometheus (for monitoring)
4. Install Slurm Operator CRDs
5. Install Slurm Operator
6. Deploy Slurm cluster

**Duration:** 10-15 minutes depending on image pull times

### 2. Customize deployment (optional)

Before running the script, customize the Slurm cluster configuration:

```bash
# Edit values to match your needs
vim values-slurm.yaml
```

Key customization options:
- Compute partition sizes and resource limits
- Storage class and PVC sizes
- Number of compute node replicas
- MariaDB credentials
- REST API exposure

### 3. Verify deployment

```bash
# Check all pods are running
kubectl -n slurm get pods

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# slurm-accounting-0            1/1     Running   0          5m
# slurm-compute-debug-0         1/1     Running   0          5m
# slurm-compute-debug-1         1/1     Running   0          5m
# slurm-controller-0            1/1     Running   0          5m
# slurm-exporter-xxx            1/1     Running   0          5m
# slurm-login-xxx               1/1     Running   0          5m
# slurm-mariadb-0               1/1     Running   0          5m
# slurm-restapi-xxx             1/1     Running   0          5m

# Check Slurm operator
kubectl -n slinky get pods
```

## Usage

### Access the login node

```bash
# Interactive shell
kubectl -n slurm exec -it $(kubectl -n slurm get pod -l app.kubernetes.io/component=login -o name | head -1) -- bash

# Once inside the login node, you have full Slurm access
sinfo          # View cluster info
squeue         # View job queue
srun hostname  # Run a simple test job
```

### Submit batch jobs

**Simple single-node job:**

```bash
# From inside the login pod
cat > test-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=test-%j.out
#SBATCH --ntasks=1
#SBATCH --time=00:01:00

echo "Running on: $(hostname)"
echo "Date: $(date)"
sleep 10
echo "Job complete!"
EOF

# Submit the job
sbatch test-job.sh

# Check status
squeue

# View output
cat test-*.out
```

**Parallel MPI job example:**

```bash
cat > mpi-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=mpi-test
#SBATCH --output=mpi-%j.out
#SBATCH --ntasks=4
#SBATCH --time=00:05:00

srun hostname
EOF

sbatch mpi-job.sh
```

### Using the REST API

If REST API is exposed (change to LoadBalancer or use port-forward):

```bash
# Port forward to access locally
kubectl -n slurm port-forward svc/slurm-restapi 8080:8080

# In another terminal, submit jobs via API
curl -X GET http://localhost:8080/slurm/v0.0.40/jobs
```

### Monitor with Prometheus

Slurm metrics are automatically exported to Prometheus (if installed):

```bash
# Check metrics endpoint
kubectl -n slurm port-forward svc/slurm-exporter 9817:9817

# Access metrics
curl http://localhost:9817/metrics
```

## Storage

### Current Configuration

**local-path** - Controller state persistence
- Slurm controller state save/restore
- ReadWriteOnce access mode
- Size: 4Gi
- PVC: `statesave-slurm-controller-0`

**What's NOT configured:**
- ❌ Shared `/home` filesystem (CephFS)
- ❌ Accounting database (MariaDB) - disabled in values-slurm.yaml
- ❌ Shared job data storage

### What This Means

**What works:**
- ✅ Submit and run jobs
- ✅ Jobs execute on compute nodes
- ✅ All Slurm commands (sinfo, squeue, srun, sbatch)
- ✅ REST API access
- ✅ Basic Slurm functionality

**Limitations:**
- ⚠️ Each pod has isolated storage
- ⚠️ No shared `/home` across nodes
- ⚠️ Jobs on different nodes can't easily share files
- ⚠️ User home directories not persistent across pod restarts

**Good for:**
- Learning Slurm commands
- Testing job submission
- Understanding HPC concepts
- Single-node jobs

**Not ideal for:**
- Multi-node MPI jobs requiring shared data
- Persistent user home directories
- Production workloads

### Adding CephFS (Optional)

To add shared storage for multi-node jobs, create a CephFS PVC and mount it on all nodes. This is an advanced configuration - consult Slinky documentation for details

## Scaling

### Add more compute nodes

Edit `values-slurm.yaml` and increase replicas:

```yaml
compute:
  partitions:
    - name: "debug"
      replicas: 4  # Increase from 2 to 4
```

Then upgrade the Helm release:

```bash
helm upgrade slurm oci://ghcr.io/slinkyproject/charts/slurm \
  --values=values-slurm.yaml \
  --version=0.4.1 \
  --namespace=slurm
```

### Add new partitions

Add additional partition definitions in `values-slurm.yaml`:

```yaml
compute:
  partitions:
    - name: "debug"
      replicas: 2
    - name: "gpu"      # New partition
      replicas: 1
      resources:
        requests:
          nvidia.com/gpu: 1
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl -n slurm describe pod <pod-name>

# Check operator logs
kubectl -n slinky logs -l app.kubernetes.io/name=slurm-operator

# Check controller logs
kubectl -n slurm logs slurm-controller-0
```

### Jobs stuck in pending

```bash
# Access login node
kubectl -n slurm exec -it $(kubectl -n slurm get pod -l app.kubernetes.io/component=login -o name | head -1) -- bash

# Inside login node, check why
squeue
scontrol show job <job-id>

# Check partition state
sinfo -Nel
```

### Storage issues

```bash
# Check PVCs
kubectl -n slurm get pvc

# Verify CephFS is available
kubectl get storageclass cephfs
```

## Uninstall

```bash
# Remove Slurm cluster
helm uninstall slurm -n slurm

# Remove Slurm operator
helm uninstall slurm-operator -n slinky
helm uninstall slurm-operator-crds

# Optional: Remove prerequisites if not used elsewhere
helm uninstall prometheus -n prometheus
helm uninstall cert-manager -n cert-manager

# Delete namespaces
kubectl delete namespace slurm slinky
```

## Configuration Reference

See [values-slurm.yaml](values-slurm.yaml) for all configurable options.

**Common settings:**
- `clusterName`: Cluster identifier (currently: "homelab-hpc")
- `nodesets.debug.replicas`: Number of compute nodes (currently: 2)
- `nodesets.debug.slurmd.resources`: CPU/memory limits per compute node
- `controller.persistence`: Controller state persistence (currently: local-path, 4Gi)
- `accounting.enabled`: Enable/disable accounting (currently: false)
- `restapi.service.type`: Service exposure type (currently: ClusterIP)

**Note:** Current configuration does NOT include:
- Shared /home storage (CephFS)
- Accounting database (MariaDB)
- These are optional and can be added later

## Resources

- [Slinky Project GitHub](https://github.com/SlinkyProject/slurm-operator)
- [Slinky Documentation](https://slinky.schedmd.com/)
- [Slurm Documentation](https://slurm.schedmd.com/documentation.html)
- [Vultr Deployment Guide](https://docs.vultr.com/how-to-automate-slurm-on-vultr-kubernetes-engine)

## Architecture Decisions

**Why Slinky over alternatives?**
- Official SchedMD project (creators of Slurm)
- Active development and community support
- Helm-based deployment (familiar to K8s users)
- Operator pattern for lifecycle management
- Includes monitoring and REST API out of the box

**Why K8s for Slurm?**
- Unified infrastructure management
- Share resources between batch (Slurm) and service (K8s) workloads
- Leverage existing K8s storage, networking, and monitoring
- Easier maintenance than separate bare-metal cluster

## Important Notes

⚠️ **First-time deployers:** See [DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md) for detailed setup instructions, common issues, and solutions encountered during the actual deployment.

**Key points:**
- This deployment uses Slinky v0.4.1 (not v0.2.1 from older guides)
- Initial pod restarts (10-15) during startup are normal
- Resource requests are tuned for homelab environments
- Accounting is disabled by default (can be enabled with MariaDB)

## Next Steps

After deployment, consider:
1. Setting up user accounts and authentication
2. Configuring job accounting and fair-share scheduling
3. Integrating with existing LDAP/AD for user management
4. Adding GPU nodes for ML/AI workloads
5. Setting up backups for MariaDB accounting database
6. Exposing REST API securely with Ingress + TLS
