# HTCondor Workload Manager - Quick Reference

## What is HTCondor?

**HTCondor** (High Throughput Condor) is a specialized workload management system for **High Throughput Computing (HTC)**. It's designed to manage massive numbers of independent, loosely-coupled jobs across distributed computing resources.

**Key Difference from Slurm/K8s**:
- **Kubernetes**: Long-running services, microservices
- **Slurm**: Tightly-coupled parallel jobs (MPI), batch computing
- **HTCondor**: High-throughput, many independent jobs, opportunistic computing

**The Mental Model**:
- HTCondor: "I have 10,000 independent simulations to run, use whatever machines are available"
- Slurm: "I need 128 cores for 4 hours for one tightly-coupled MPI job"
- Kubernetes: "Keep these 3 web server replicas running continuously"

---

## Architecture (4 Core Daemons)

```
┌─────────────────────────────────────────────────────────┐
│              CENTRAL MANAGER                            │
│                                                         │
│  ┌──────────────────┐      ┌──────────────────┐       │
│  │ condor_collector │      │ condor_negotiator│       │
│  │ - Collects state │      │ - Matchmaking    │       │
│  │ - ClassAd DB     │      │ - Job scheduling │       │
│  └──────────────────┘      └──────────────────┘       │
└─────────────────────────────────────────────────────────┘
           ▲                            │
           │                            │
           │ ClassAds                   │ Matches
           │                            ▼
    ┌──────┴────────┐          ┌────────────────┐
    │               │          │                │
┌───▼──────────┐  ┌─▼────────────┐  ┌─▼────────────┐
│ SUBMIT NODE  │  │ EXECUTE NODE │  │ EXECUTE NODE │
│              │  │              │  │              │
│condor_schedd │  │condor_startd │  │condor_startd │
│ - Job queue  │  │ - Run jobs   │  │ - Run jobs   │
│ - Submission │  │ - Advertise  │  │ - Advertise  │
│              │  │   resources  │  │   resources  │
└──────────────┘  └──────────────┘  └──────────────┘
```

### 1. condor_collector - The "Information Hub"
- Runs on the central manager
- Collects status information from all daemons
- Maintains ClassAd database of resources and jobs
- Think: "Central registry"

### 2. condor_negotiator - The "Matchmaker"
- Runs on the central manager
- Performs matchmaking between jobs and resources
- Implements scheduling policies and priorities
- Allocates resources to waiting jobs
- Think: "Job scheduler and resource broker"

### 3. condor_schedd - The "Job Manager"
- Runs on submit nodes (access points)
- Manages job queue for users
- Tracks job status
- Handles job submission and removal
- Think: "Job queue manager"

### 4. condor_startd - The "Worker"
- Runs on execute nodes (compute resources)
- Advertises available resources via ClassAds
- Executes jobs assigned by negotiator
- Enforces local resource policies
- Think: "Execution agent"

---

## Key Concepts

### High Throughput Computing (HTC)
- **HTC**: Many independent jobs over long periods (weeks/months)
- **HPC**: Tightly-coupled parallel jobs over short periods (hours/days)
- HTCondor excels at HTC: 10,000 simulations, parameter sweeps, embarrassingly parallel workloads

### ClassAds (Classified Advertisements)
HTCondor's unique matching mechanism:
- Jobs advertise requirements: "I need 4GB RAM, Linux, GPU"
- Resources advertise capabilities: "I have 64GB RAM, 8 cores, NVIDIA GPU"
- Negotiator matches advertisements based on constraints

```text
Job ClassAd Example:
  Requirements = (OpSys == "LINUX") && (Memory >= 4096)
  RequestCpus = 4
  RequestMemory = 4096
  RequestGPUs = 1

Machine ClassAd Example:
  OpSys = "LINUX"
  TotalMemory = 32768
  Cpus = 16
  HasGPU = True
```

### Universe
Execution environment for jobs:
- **Vanilla**: Standard Unix executables (most common)
- **Docker**: Run jobs in Docker containers
- **VM**: Run jobs in virtual machines
- **Standard**: Checkpointing and migration support
- **Grid**: Submit to external grids
- **Local**: Run on submit machine

### Job Lifecycle States
- **Idle**: Waiting to run
- **Running**: Executing on a machine
- **Held**: Suspended due to error or user action
- **Completed**: Finished successfully
- **Removed**: Cancelled by user

### Opportunistic Computing
HTCondor can harness idle desktop workstations, cloud resources, and heterogeneous systems:
- Automatically scavenges idle resources
- Jobs can be preempted when owner returns
- Checkpoint and resume capabilities

---

## Common Commands

### Job Submission

```bash
condor_submit job.sub           # Submit job from submit file
condor_submit -i                # Interactive job
condor_submit_dag workflow.dag  # Submit DAG (workflow)
```

### Monitoring

```bash
condor_q                        # View your job queue
condor_q -nobatch               # Detailed view (one line per job)
condor_q -run                   # Show running jobs with execution hosts
condor_q -hold                  # Show held jobs
condor_q -analyze <jobid>       # Why isn't this job running?

condor_status                   # View available resources
condor_status -compact          # Summarized view
condor_status -submitters       # Show all submitters
```

### Management

```bash
condor_rm <jobid>               # Remove a job
condor_rm <username>            # Remove all jobs for user
condor_rm -all                  # Remove all your jobs

condor_hold <jobid>             # Put job on hold
condor_release <jobid>          # Release held job

condor_ssh_to_job <jobid>       # SSH to running job (debug)
```

### History & Analysis

```bash
condor_history                  # View completed jobs
condor_history <username>       # History for specific user
condor_history <jobid>          # Details for specific job

condor_userprio                 # Show user priorities
condor_config_val <param>       # Show config parameter value
```

---

## HTCondor Submit File Example

### Basic Submit File

```bash
# job.sub - Simple job submission

universe        = vanilla
executable      = /bin/sleep
arguments       = 60

log             = job.log
output          = job.out
error           = job.err

request_cpus    = 1
request_memory  = 2GB
request_disk    = 1GB

# Requirements and preferences
requirements    = (OpSys == "LINUX")
rank            = Memory

# Queue 1 job
queue
```

### Multiple Jobs (Parameter Sweep)

```bash
# parameter_sweep.sub - Run 100 variations

universe        = vanilla
executable      = simulation.sh
arguments       = $(Process)

log             = logs/job_$(Process).log
output          = logs/job_$(Process).out
error           = logs/job_$(Process).err

request_cpus    = 2
request_memory  = 4GB

# Queue 100 jobs (Process = 0-99)
queue 100
```

### Docker Job

```bash
# docker_job.sub - Run job in container

universe                = docker
docker_image            = python:3.11

executable              = train_model.py
arguments               = --epochs 100 --batch-size 32

transfer_input_files    = data.csv,config.json
should_transfer_files   = YES
when_to_transfer_output = ON_EXIT

request_cpus            = 4
request_memory          = 8GB
request_gpus            = 1

log    = training.log
output = training.out
error  = training.err

queue
```

### DAG Workflow (Dependencies)

```bash
# workflow.dag - Multi-step workflow

# Job definitions
JOB A preprocess.sub
JOB B analyze.sub
JOB C visualize.sub

# Dependencies
PARENT A CHILD B
PARENT B CHILD C

# B runs after A completes
# C runs after B completes
```

---

## HTCondor vs Other Systems

| Aspect | HTCondor | Slurm | Kubernetes |
|--------|----------|-------|------------|
| **Primary Use** | High-throughput, many independent jobs | HPC, tightly-coupled parallel jobs | Microservices, long-running apps |
| **Job Count** | Thousands to millions | Hundreds to thousands | Pods (typically hundreds) |
| **Job Coupling** | Loosely coupled, independent | Tightly coupled (MPI) | Independent containers |
| **Scheduling** | Matchmaking (ClassAds) | Fair-share, backfill | Bin-packing |
| **Checkpointing** | Yes (Standard universe) | Limited | Via application |
| **Job Migration** | Yes | Limited | Pod rescheduling |
| **Opportunistic** | Excellent (idle scavenging) | Limited | Limited |
| **Resource Model** | Flexible matching | Node/partition based | Pod requests/limits |
| **Heterogeneity** | Excellent (mixed resources) | Good | Good |
| **DAG Workflows** | Native (DAGMan) | Via scripts | Via tools (Argo) |
| **Priority System** | User priorities, preemption | Fair-share | Priority classes |
| **Job Definition** | Submit files | Batch scripts | YAML manifests |

**The Sweet Spots**:
- **HTCondor**: Parameter sweeps, Monte Carlo simulations, grid computing, desktop scavenging
- **Slurm**: MPI jobs, supercomputers, HPC clusters
- **Kubernetes**: Web services, microservices, containerized apps

---

## When to Use HTCondor

### Use HTCondor when:
- Running thousands of independent jobs
- Parameter sweeps and ensemble simulations
- Opportunistic computing (using idle resources)
- Heterogeneous resource pools (different OS, hardware)
- Need job migration and checkpointing
- Workflow management with dependencies (DAGs)
- Grid computing and distributed resources
- Desktop scavenging in offices/labs

### Examples:
- **Drug discovery**: Screen 1 million compounds
- **Climate modeling**: Run 10,000 simulations with different parameters
- **Monte Carlo**: Generate millions of random samples
- **Data analysis**: Process 100,000 data files independently
- **CI/CD**: Distributed build and test jobs
- **Research computing**: Campus-wide resource sharing

### Don't use HTCondor when:
- Need real-time scheduling
- Tightly-coupled MPI applications (use Slurm)
- Long-running services (use Kubernetes)
- Need guaranteed completion times
- Single large parallel job

---

## HTCondor's Unique Features

### 1. ClassAd Matchmaking
Flexible, expressive matching language:
```bash
# Job requirements
Requirements = (OpSys == "LINUX") && (Arch == "X86_64") && \
               (Memory >= 8192) && (HasGPU == True) && \
               (GPUMemory >= 16384)

# Preferences (rank machines)
Rank = (Memory * 2) + Cpus
```

### 2. Job Checkpointing
Save job state and resume:
- Survive machine failures
- Migrate to better resources
- Preempt gracefully

### 3. DAGMan (Workflow Manager)
Express complex workflows:
```bash
# Multi-stage pipeline
JOB Fetch fetch_data.sub
JOB Process process_data.sub
JOB Analyze analyze_results.sub
JOB Report generate_report.sub

PARENT Fetch CHILD Process
PARENT Process CHILD Analyze
PARENT Analyze CHILD Report

# Retry failed jobs
RETRY Process 3
```

### 4. Flocking
Jobs can "flock" to other HTCondor pools:
- Submit locally, run remotely
- Seamless multi-pool access
- Expand capacity dynamically

### 5. File Transfer
Automatic file staging:
```bash
transfer_input_files = input1.dat,input2.dat,config.json
transfer_output_files = results.out,metrics.csv
should_transfer_files = YES
when_to_transfer_output = ON_EXIT
```

---

## Interview Cheat Sheet

### THE BIG 5 COMMANDS
```bash
condor_submit job.sub    # Submit job
condor_q                 # View queue
condor_status            # View resources
condor_rm <jobid>        # Remove job
condor_history           # Job history
```

### SUBMIT FILE ESSENTIALS
```bash
universe        = vanilla          # Execution environment
executable      = ./my_program     # What to run
arguments       = arg1 arg2        # Command-line args

log             = job.log          # HTCondor log
output          = job.out          # stdout
error           = job.err          # stderr

request_cpus    = 4                # CPU cores needed
request_memory  = 8GB              # Memory needed
request_disk    = 10GB             # Disk space needed
request_gpus    = 1                # GPUs needed

requirements    = (...)            # Machine constraints
rank            = (...)            # Machine preferences

queue                              # Submit job(s)
```

---

## Common Interview Questions

### "What is HTCondor?"
"HTCondor is a workload management system specialized for High Throughput Computing. It manages thousands of independent jobs across distributed, heterogeneous resources using a unique ClassAd matchmaking system. It's used extensively in research computing, grid computing, and environments where you need to harness opportunistic or idle resources."

### "How does HTCondor differ from Slurm?"
"HTCondor excels at high-throughput workloads - thousands of independent jobs that can run anywhere. Slurm is optimized for HPC with tightly-coupled parallel jobs using MPI. HTCondor's matchmaking system is more flexible for heterogeneous resources, and it has better support for job migration, checkpointing, and opportunistic computing. Slurm is better for dedicated HPC clusters running large parallel simulations."

### "Explain HTCondor's architecture"
"HTCondor uses four main daemons: The condor_collector maintains a database of resource and job ClassAds on the central manager. The condor_negotiator performs matchmaking between jobs and resources. On submit nodes, condor_schedd manages the job queue. On execute nodes, condor_startd advertises resources and runs jobs. Jobs and resources advertise their requirements and capabilities via ClassAds, and the negotiator matches them."

### "What are ClassAds?"
"ClassAds are HTCondor's unique matching mechanism - think of them as classified advertisements. Jobs advertise requirements like 'I need Linux, 8GB RAM, and a GPU' while machines advertise capabilities like 'I have 64GB RAM, 16 cores, NVIDIA GPU'. The negotiator matches these advertisements using boolean logic and ranking expressions."

### "What is a DAG in HTCondor?"
"DAG stands for Directed Acyclic Graph - it's HTCondor's workflow management system called DAGMan. It lets you express job dependencies, like 'job B runs after job A completes'. You can build complex multi-stage pipelines with error handling, retries, and conditional execution. It's particularly useful for data processing pipelines and multi-step scientific workflows."

### "When would you use HTCondor vs Kubernetes?"
"Use HTCondor for batch computational workloads - parameter sweeps, Monte Carlo simulations, data processing where you have many independent jobs. Use Kubernetes for long-running services, microservices, and web applications. HTCondor is designed for jobs that finish, K8s is designed for services that run continuously. Some organizations use both: K8s for services, HTCondor for batch computation."

---

## Real-World Example: Parameter Sweep

### Scenario
Run climate simulations with 1000 different parameter combinations.

### Submit File
```bash
# climate_sweep.sub

universe        = vanilla
executable      = /usr/bin/python3
arguments       = simulate_climate.py --temp=$(temp) --co2=$(co2)

transfer_input_files = simulate_climate.py,base_config.json
should_transfer_files = YES
when_to_transfer_output = ON_EXIT

log             = logs/climate_$(Process).log
output          = results/climate_$(Process).out
error           = logs/climate_$(Process).err

request_cpus    = 2
request_memory  = 4GB
request_disk    = 2GB

# Only run on Linux machines with at least 4GB RAM
requirements    = (OpSys == "LINUX") && (Memory >= 4096)

# Prefer machines with more memory
rank            = Memory

# Queue 1000 jobs with different parameters
queue temp,co2 from parameters.csv
```

### parameters.csv
```csv
temp,co2
15.0,400
15.5,400
16.0,400
15.0,420
15.5,420
...
(1000 rows)
```

### Submit and Monitor
```bash
# Submit the job
$ condor_submit climate_sweep.sub
Submitting job(s)..................................
1000 job(s) submitted to cluster 12345.

# Monitor progress
$ condor_q
-- Schedd: submit.example.com : <192.168.1.100:9618?...
 ID        OWNER     SUBMITTED     RUN_TIME ST PRI SIZE CMD
12345.0   adam      10/21 09:00   0+00:15:42 R  0    4.0  python3 simulate_climate.py
12345.1   adam      10/21 09:00   0+00:15:38 R  0    4.0  python3 simulate_climate.py
...
750 jobs; 250 completed, 0 removed, 50 idle, 450 running, 0 held, 0 suspended

# Check completed jobs
$ condor_history -userlog logs/climate_0.log
```

---

## Advanced: DAG Workflow Example

### Multi-Stage Data Pipeline
```bash
# pipeline.dag

# Define jobs
JOB DownloadData download.sub
JOB ProcessData process.sub
JOB TrainModel train.sub
JOB ValidateModel validate.sub
JOB GenerateReport report.sub

# Define dependencies
PARENT DownloadData CHILD ProcessData
PARENT ProcessData CHILD TrainModel
PARENT TrainModel CHILD ValidateModel
PARENT ValidateModel CHILD GenerateReport

# Retry failed jobs
RETRY ProcessData 3
RETRY TrainModel 2

# Run script on completion
SCRIPT POST ValidateModel check_accuracy.sh $JOB $RETURN

# Variables
VARS TrainModel epochs="100" batch_size="32"
VARS ValidateModel model_path="models/model_$(cluster).pkl"
```

### Submit DAG
```bash
$ condor_submit_dag pipeline.dag
File for submitting this DAG to HTCondor: pipeline.dag.condor.sub
-----------------------------------------------------------------------
Submitting job(s).
1 job(s) submitted to cluster 12346.
```

---

## HTCondor Universes Explained

| Universe | Use Case | Features |
|----------|----------|----------|
| **Vanilla** | Standard executables | Most common, simple jobs |
| **Docker** | Containerized jobs | Run in Docker containers |
| **VM** | Virtual machines | Full VM isolation |
| **Standard** | Checkpointable jobs | Process checkpointing, migration |
| **Grid** | External grids | Submit to Globus, EC2, etc. |
| **Local** | Local execution | Run on submit machine |
| **Parallel** | MPI jobs | Parallel computing (less common) |
| **Java** | Java applications | Legacy, rarely used |

**Most Used**: Vanilla (90%), Docker (growing), Standard (specialized)

---

## Key Takeaways

1. **HTCondor = High-Throughput Computing** - Many independent jobs, not tightly-coupled parallel
2. **ClassAd Matchmaking** - Unique flexible matching between jobs and resources
3. **4 core daemons** - collector, negotiator, schedd, startd
4. **Opportunistic computing** - Excellent at scavenging idle resources
5. **DAGMan workflows** - Native support for complex job dependencies
6. **Job migration & checkpointing** - Resilience and flexibility
7. **Complements Slurm/K8s** - Different tools for different workload patterns

---

## HTCondor vs Slurm vs K8s Quick Guide

**Choose HTCondor if:**
- Thousands of independent jobs
- Parameter sweeps, Monte Carlo
- Heterogeneous, opportunistic resources
- Need job migration/checkpointing
- Workflow dependencies (DAGs)

**Choose Slurm if:**
- Tightly-coupled MPI jobs
- Dedicated HPC cluster
- Traditional supercomputing workloads
- Fair-share among research groups

**Choose Kubernetes if:**
- Long-running services
- Microservices architecture
- Container orchestration
- Web applications, APIs

**Use Multiple?**
Many organizations run:
- **HTCondor** for batch computation
- **Slurm** for HPC workloads
- **Kubernetes** for services

All three can coexist!

---

## Common Pitfalls & Tips

### Pitfall 1: File Transfer
**Problem**: Forgetting to transfer input files
**Solution**: Always specify `transfer_input_files` and `should_transfer_files = YES`

### Pitfall 2: Job Matching
**Problem**: Jobs stuck idle, no matching resources
**Solution**: Use `condor_q -analyze <jobid>` to see why job isn't matching

### Pitfall 3: Resource Requests
**Problem**: Jobs held because they exceed resources
**Solution**: Set realistic `request_memory`, `request_disk`, `request_cpus`

### Pitfall 4: Log Files
**Problem**: Can't debug failed jobs
**Solution**: Always specify `log`, `output`, and `error` files

### Pro Tips
1. Use `$(Process)` in filenames for multiple jobs
2. Test with `queue 1` before `queue 10000`
3. Use DAGs for multi-step workflows
4. Monitor with `condor_watch_q` for live updates
5. Use `condor_ssh_to_job` to debug running jobs

---

*References: HTCondor Manual 25.1.0, Wisconsin HTCondor team, CERN tutorials, production deployments*
