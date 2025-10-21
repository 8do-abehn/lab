# Slurm Workload Manager - Quick Reference

## What is Slurm?

**Slurm** (Simple Linux Utility for Resource Management) is the dominant workload manager in HPC - used on ~60% of the TOP500 supercomputers. Think of it as **Kubernetes for scientific computing and HPC clusters**.

**Key Difference from K8s**:
- **Kubernetes**: Long-running services, microservices, web apps
- **Slurm**: Batch jobs, scientific simulations, AI training, research workloads

---

## Architecture (3 Core Daemons)

```
┌─────────────────────────────────────────┐
│         slurmctld (Controller)          │
│    - Central manager                    │
│    - Job scheduler                      │
│    - Resource allocation                │
│    - Queue management                   │
│    - HA with backup controller          │
└─────────────────────────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
┌───────▼──┐  ┌────▼────┐  ┌─▼────────┐
│ slurmd   │  │ slurmd  │  │ slurmd   │
│ (Node 1) │  │(Node 2) │  │ (Node 3) │
│          │  │         │  │          │
│ Executes │  │Executes │  │ Executes │
│ jobs     │  │jobs     │  │ jobs     │
└──────────┘  └─────────┘  └──────────┘

Optional:
- slurmdbd: Database daemon for accounting
- slurmrestd: REST API interface
```

### 1. slurmctld - The "brain"
- Runs on 1-2 control nodes (HA)
- Schedules jobs
- Manages queue
- Tracks cluster state

### 2. slurmd - The "workers"
- Runs on every compute node
- Executes jobs assigned by controller
- Reports node status back

### 3. slurmdbd - The "accountant" (optional)
- Stores job history
- Usage accounting
- Multi-cluster support

---

## Key Concepts

### Nodes
Physical/virtual compute resources
- States: idle, allocated, down, draining

### Partitions
Logical groupings of nodes (like K8s namespaces)
- Example: `gpu`, `highmem`, `debug`
- Different limits, priorities, time limits

### Jobs
User's resource allocation request
- Exclusive or shared access to nodes
- Time-limited

### Job Steps
Tasks within a job
- Parallel execution units
- Can run multiple steps in one job

---

## Common Commands

### Job Submission
```bash
sbatch script.sh              # Submit batch job from script
srun ./my_program             # Run interactive job immediately
salloc -N 4 -t 60             # Allocate 4 nodes for 60 minutes (interactive)
```

### Monitoring
```bash
squeue                         # View job queue (like kubectl get pods)
squeue -u username             # View your jobs only
sinfo                          # View cluster/partition status (like kubectl get nodes)
scontrol show job <jobid>      # Detailed job info
scontrol show node <nodename>  # Detailed node info
```

### Management
```bash
scancel <jobid>                # Cancel a job (like kubectl delete)
scancel -u username            # Cancel all your jobs
scontrol hold <jobid>          # Pause a job
scontrol release <jobid>       # Resume a paused job
```

### Accounting & History
```bash
sacct                          # Job accounting data
sacct -j <jobid> --format=...  # Detailed job statistics
```

---

## Slurm Script Example

```bash
#!/bin/bash
#SBATCH --job-name=my_simulation
#SBATCH --nodes=4                # Request 4 nodes
#SBATCH --ntasks-per-node=16     # 16 tasks per node = 64 total
#SBATCH --time=02:00:00          # 2 hour time limit
#SBATCH --partition=gpu          # Use GPU partition
#SBATCH --output=job_%j.log      # %j = jobID

# Your actual work here
srun ./simulation_binary input.dat
```

---

## Slurm vs Kubernetes

| Aspect | Slurm | Kubernetes |
|--------|-------|------------|
| **Primary Use** | Batch jobs, HPC, scientific computing | Microservices, long-running apps, web services |
| **Workload Type** | Finite jobs with start/end | Continuously running services |
| **Scheduling** | Fair-share, priority queues, backfill | Bin-packing, resource requests/limits |
| **Resource Model** | Whole nodes or CPUs | Pods with granular CPU/memory |
| **Job Definition** | Batch scripts (`sbatch`) | YAML manifests |
| **Parallelism** | MPI-aware, tightly-coupled parallel jobs | Loosely-coupled containers |
| **Networking** | High-speed interconnects (InfiniBand) | Overlay networks (Calico, Flannel) |
| **Storage** | Shared filesystems (Lustre, GPFS) | PVs, PVCs, object storage |
| **Users** | Multi-tenant research users | Application teams |
| **Accounting** | Job usage, fairshare, billing | Resource quotas |

**The Mental Model**:
- **Slurm**: "I need 128 cores for 4 hours to run this simulation"
- **Kubernetes**: "Keep this API server running with 3 replicas"

---

## When to Use Each

### Use Slurm when:
- Running batch computational jobs (simulations, ML training)
- Need whole-node allocations
- MPI-based parallel applications
- Scientific/research computing
- Fair-share scheduling among multiple users/groups
- HPC workloads on supercomputers

### Use Kubernetes when:
- Microservices architecture
- Web applications and APIs
- Container orchestration
- CI/CD pipelines
- Need auto-scaling based on load
- Cloud-native applications

### Can they coexist?
**YES!**
- Some orgs use **Slurm for batch jobs** + **K8s for services**
- Projects like **Volcano** bring Slurm-like batch scheduling to K8s
- **Kubeflow** runs ML training on K8s with batch-like semantics

---

## Slurm vs Other Workload Managers

### Slurm vs PBS/Torque
- PBS is older, commercial (PBS Pro) or open-source (OpenPBS)
- Slurm is more modern, actively developed, open-source
- Slurm has better scalability (scales to 100k+ nodes)
- Similar commands: `qsub` (PBS) ≈ `sbatch` (Slurm)

### Slurm vs LSF (IBM)
- LSF is commercial, enterprise support
- Popular in finance/industry
- Slurm dominates in academia/research

### Slurm vs HTCondor
- HTCondor: High-throughput computing (many small jobs)
- Slurm: Both HPC and HTC workloads
- HTCondor: Job migration, checkpointing
- Slurm: Better for tightly-coupled MPI jobs

### Slurm vs SGE (Sun Grid Engine)
- SGE is legacy, less active development
- Slurm is the modern replacement

---

## Why Slurm is Popular

1. **Open source** - Free, community-driven
2. **Scalable** - Handles 100,000+ nodes
3. **Fair-share scheduling** - Ensures equitable resource distribution
4. **MPI integration** - Native support for parallel computing
5. **Accounting** - Detailed job usage tracking
6. **Plugin architecture** - Highly customizable
7. **Active development** - Regular updates, modern features

---

## Modern Slurm Trends (2025)

- **AI/ML workloads** - GPU scheduling, PyTorch/TensorFlow jobs
- **Cloud integration** - Hybrid on-prem + cloud bursting
- **Container support** - Can run Docker/Singularity containers
- **REST API** - Modern programmatic access via `slurmrestd`

### Slurm + Containers

```bash
# Run Singularity container with Slurm
sbatch --wrap="singularity exec container.sif python train_model.py"

# GPU job with container
sbatch --gres=gpu:4 --wrap="singularity exec --nv tensorflow.sif ./job.sh"
```

---

## Interview Cheat Sheet

### THE BIG 5 COMMANDS
```bash
sinfo          # Cluster status
squeue         # Job queue
sbatch job.sh  # Submit job
scancel 123    # Cancel job
sacct          # Job history
```

### RESOURCE SPECS (in job script)
```bash
#SBATCH --nodes=4              # Number of nodes
#SBATCH --ntasks=64            # Total tasks (MPI ranks)
#SBATCH --cpus-per-task=2      # CPUs per task (OpenMP threads)
#SBATCH --mem=32G              # Memory per node
#SBATCH --time=01:30:00        # Wall time (HH:MM:SS)
#SBATCH --gres=gpu:2           # Generic resources (2 GPUs)
#SBATCH --partition=compute    # Which partition to use
```

---

## Common Interview Questions

### "What is Slurm?"
"Slurm is an open-source workload manager and job scheduler designed for HPC clusters. It handles resource allocation, job queuing, and execution for batch computational workloads. It's used on about 60% of the TOP500 supercomputers."

### "How does Slurm differ from Kubernetes?"
"While both orchestrate workloads, Slurm focuses on batch jobs with finite execution times - think scientific simulations or ML training. Kubernetes is designed for long-running services like web apps. Slurm uses fair-share scheduling for multi-tenant research environments, while K8s uses bin-packing for efficient resource utilization."

### "Explain Slurm's architecture"
"Slurm uses a centralized architecture with slurmctld as the controller daemon managing scheduling and state, slurmd daemons on each compute node executing jobs, and optionally slurmdbd for accounting. The controller can run in HA mode with a backup. It's a lightweight design that scales to 100,000+ nodes."

### "What's a partition in Slurm?"
"Partitions are logical groupings of nodes, similar to queues in other schedulers. They let you separate resources by use case - like 'gpu', 'highmem', or 'debug' partitions - each with different policies, time limits, and priorities."

### "How would you submit a job?"
"For batch jobs, I'd create a script with `#SBATCH` directives specifying resources, then submit with `sbatch script.sh`. For interactive work, I'd use `srun` for immediate execution or `salloc` to allocate resources for manual commands."

---

## Real-World Example: ML Training Job

```bash
#!/bin/bash
#SBATCH --job-name=bert_training
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4      # 4 GPUs per node
#SBATCH --gres=gpu:4
#SBATCH --time=24:00:00
#SBATCH --partition=gpu
#SBATCH --output=training_%j.log

# Load modules (environment setup)
module load cuda/12.0 python/3.11

# Activate virtual environment
source ~/venv/bin/activate

# Run distributed training
srun python -m torch.distributed.launch \
    --nproc_per_node=4 \
    --nnodes=2 \
    train_bert.py \
    --model bert-large \
    --batch-size 32 \
    --epochs 100
```

This demonstrates:
- GPU allocation (`--gres`)
- Multi-node jobs (`--nodes=2`)
- Environment setup (modules)
- Distributed computing (`srun` with PyTorch)

---

## Key Takeaways

1. **Slurm = HPC's workload manager** - Batch jobs, not services
2. **3 main daemons** - slurmctld (controller), slurmd (workers), slurmdbd (accounting)
3. **Fair-share scheduling** - Ensures equitable resource distribution among users
4. **MPI-native** - Built for tightly-coupled parallel computing
5. **K8s complement, not replacement** - Different tools for different jobs
6. **Modern features** - Container support, REST API, cloud bursting

---

## K8s Parallels (for K8s experts)

- Slurm partitions ≈ K8s node pools
- `squeue` ≈ `kubectl get pods`
- `sinfo` ≈ `kubectl get nodes`
- `scancel` ≈ `kubectl delete`
- Both handle resource allocation, just different workload patterns

---

*References: Official Slurm documentation, TOP500 statistics, 2025 HPC trends*
