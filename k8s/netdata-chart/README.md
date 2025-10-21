# Netdata Helm Chart

This chart deploys Netdata monitoring to your Kubernetes cluster with pre-configured claiming settings.

## Quick Start

```bash
# Run the quickstart script for interactive setup
./quickstart.sh
```

Or manually:

```bash
helm repo add netdata https://netdata.github.io/helmchart/
helm repo update
helm install netdata netdata/netdata -f values.yaml
```

## Files

- `values.yaml` - Basic configuration with inline secrets (not recommended for production)
- `values-with-secrets.yaml` - Configuration using Kubernetes secrets (recommended)
- `secret.yaml.example` - Example Kubernetes secret template
- `Chart.yaml` - Helm chart metadata
- `DEPLOYMENT.md` - Comprehensive deployment guide with security options
- `quickstart.sh` - Interactive installation script

## Prerequisites

- Kubernetes cluster (k3s)
- Helm 3.x
- kubectl configured
- **IMPORTANT:** Host-based Netdata must NOT be running on k3s nodes (see below)

### Remove Host-Based Netdata from k3s Nodes

Netdata child pods use `hostNetwork: true` and bind to port 19999. If Netdata is already installed on your k3s nodes, you must remove it first to avoid port conflicts.

**Via Ansible:**
```bash
ansible k3s_cluster -i /path/to/ansible/inventory.ini \
  -m apt -a "name=netdata state=absent purge=yes" --become
```

**Verify removal:**
```bash
ansible k3s_cluster -i /path/to/ansible/inventory.ini \
  -m shell -a "ps aux | grep '[n]etdata' | wc -l"
# Should return 0 on each node
```

## Deployment Options

### 1. Simple (Development Only)
```bash
helm install netdata netdata/netdata -f values.yaml
```

### 2. With Kubernetes Secrets (Recommended)
```bash
# Create secret with correct key names (NETDATA_CLAIM_TOKEN and NETDATA_CLAIM_ROOMS)
kubectl create secret generic netdata-claiming \
  --from-literal=NETDATA_CLAIM_TOKEN='<your-claim-token>' \
  --from-literal=NETDATA_CLAIM_ROOMS='<your-room-id>'

# Install
helm install netdata netdata/netdata -f values-with-secrets.yaml
```

**Get your credentials from Netdata Cloud:**
1. Log in to https://app.netdata.cloud/
2. Go to your Space → Nodes → Add Nodes
3. Copy the **Claim Token** and **Room ID**

### 3. Advanced Options
See [DEPLOYMENT.md](DEPLOYMENT.md) for Sealed Secrets, External Secrets Operator, and other secure methods.

## Configuration

Key configurations:

- `image.tag: stable` - Netdata image version
- `parent.claiming` - Parent node claiming (token, rooms)
- `child.claiming` - Child node claiming (token, rooms)

## Verification

```bash
# Check pods
kubectl get pods -l app=netdata

# View logs
kubectl logs -l app=netdata --tail=50

# Verify claiming
kubectl logs -l app=netdata | grep -i claim
```

## Upgrading

```bash
helm upgrade netdata netdata/netdata -f values.yaml
```

## Uninstalling

```bash
helm uninstall netdata
```

## Security

**⚠️ IMPORTANT:** The default `values.yaml` contains sensitive tokens!

1. For production, use `values-with-secrets.yaml` with Kubernetes secrets
2. Never commit `secret.yaml` to Git (already in `.gitignore`)
3. See [DEPLOYMENT.md](DEPLOYMENT.md) for secure deployment patterns
4. Consider using Sealed Secrets or External Secrets Operator for GitOps

## Troubleshooting

### Child pods in CrashLoopBackOff with "Address already in use"

**Symptom:**
```bash
kubectl get pods -l app=netdata
# netdata-child-xxx shows CrashLoopBackOff

kubectl logs netdata-child-xxx
# Error: Cannot bind to port 19999: Address already in use
```

**Cause:** Host-based Netdata is still running on k3s nodes

**Fix:**
```bash
# Check what's using port 19999 on nodes
ansible k3s_cluster -i /path/to/ansible/inventory.ini \
  -m shell -a "ss -tlnp | grep 19999"

# Remove host-based Netdata
ansible k3s_cluster -i /path/to/ansible/inventory.ini \
  -m apt -a "name=netdata state=absent purge=yes" --become

# Delete and restart child pods
kubectl delete pods -l role=child

# Verify they start successfully
kubectl get pods -l app=netdata
```

### Incorrect secret format error

**Symptom:**
```
Error: cannot unmarshal number into Go struct field EnvVar.name of type string
```

**Cause:** Using `env` array format instead of `envFrom` in values file, or incorrect secret key names

**Fix:** Ensure your `values-with-secrets.yaml` uses `envFrom`:
```yaml
parent:
  envFrom:
    - secretRef:
        name: netdata-claiming

child:
  envFrom:
    - secretRef:
        name: netdata-claiming
```

And ensure secret has correct key names:
```bash
kubectl get secret netdata-claiming -o jsonpath='{.data}' | jq 'keys'
# Should show: ["NETDATA_CLAIM_ROOMS", "NETDATA_CLAIM_TOKEN"]

# If incorrect, recreate:
kubectl delete secret netdata-claiming
kubectl create secret generic netdata-claiming \
  --from-literal=NETDATA_CLAIM_TOKEN='<token>' \
  --from-literal=NETDATA_CLAIM_ROOMS='<room-id>'
```

### Pods not appearing in Netdata Cloud

**Check claiming status:**
```bash
kubectl logs -l app=netdata,role=parent | grep -i claim
kubectl logs -l app=netdata,role=child | grep -i claim
```

**Verify secret values:**
```bash
kubectl get secret netdata-claiming -o jsonpath='{.data.NETDATA_CLAIM_TOKEN}' | base64 -d
kubectl get secret netdata-claiming -o jsonpath='{.data.NETDATA_CLAIM_ROOMS}' | base64 -d
```

**Force re-claim:**
```bash
# Restart pods to re-attempt claiming
kubectl rollout restart daemonset netdata-child
kubectl rollout restart deployment netdata-parent
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Netdata Cloud                   │
│      https://app.netdata.cloud          │
└─────────────────▲───────────────────────┘
                  │
                  │ Metrics streaming
                  │
    ┌─────────────┴──────────────┐
    │                            │
┌───┴────────┐          ┌────────┴────┐
│  Parent    │          │  Children   │
│ (1 pod)    │◄─────────│ (DaemonSet) │
│            │  Metrics │  1 per node │
└────────────┘          └─────────────┘
                              │
                              │ hostNetwork: true
                              │ Monitors host metrics
                              │
                        ┌─────┴──────┐
                        │  k3s nodes │
                        └────────────┘
```

**Components:**
- **Parent:** Aggregates metrics from children, sends to Cloud
- **Children:** DaemonSet pods running on each k3s node with `hostNetwork: true`
- **k8s-state:** Monitors Kubernetes API for cluster-level metrics

## Support

For Netdata-specific issues, see [Netdata documentation](https://learn.netdata.cloud/docs)
