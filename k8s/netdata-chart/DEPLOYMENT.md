# Netdata Deployment Guide

This guide covers different methods to deploy Netdata with varying levels of security.

## Option 1: Direct Values (Least Secure)

Simple but exposes secrets in values file.

```bash
helm install netdata netdata/netdata -f values.yaml
```

**Pros:** Simple, easy to get started
**Cons:** Secrets visible in values file and Helm history

---

## Option 2: Kubernetes Secrets (Recommended)

Store sensitive data in Kubernetes secrets, reference them in your deployment.

### Step 1: Create the secret

```bash
# Copy and edit the example
cp secret.yaml.example secret.yaml
# Edit secret.yaml with your actual token and rooms

# Apply the secret
kubectl apply -f secret.yaml
```

### Step 2: Install Netdata

```bash
helm install netdata netdata/netdata -f values-with-secrets.yaml
```

**Pros:** Secrets managed by Kubernetes, not in Helm values
**Cons:** Still visible to anyone with kubectl access

---

## Option 3: Sealed Secrets (Most Secure)

Use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) for GitOps-friendly encrypted secrets.

### Step 1: Install Sealed Secrets Controller

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets
```

### Step 2: Create a Sealed Secret

```bash
# Create the secret and seal it
kubectl create secret generic netdata-claiming \
  --from-literal=claiming-token='YOUR_TOKEN' \
  --from-literal=claiming-rooms='YOUR_ROOM_ID' \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f sealed-secret.yaml
```

### Step 3: Install Netdata

```bash
helm install netdata netdata/netdata -f values-with-secrets.yaml
```

**Pros:** Safe to commit to Git, encrypted at rest
**Cons:** Requires additional setup

---

## Option 4: External Secrets Operator

Use [External Secrets Operator](https://external-secrets.io/) to sync from external secret managers (AWS Secrets Manager, Vault, etc.).

### Step 1: Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets
```

### Step 2: Create ExternalSecret resource

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: netdata-claiming
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager  # or your provider
    kind: SecretStore
  target:
    name: netdata-claiming
  data:
    - secretKey: claiming-token
      remoteRef:
        key: netdata/claiming-token
    - secretKey: claiming-rooms
      remoteRef:
        key: netdata/claiming-rooms
```

### Step 3: Install Netdata

```bash
helm install netdata netdata/netdata -f values-with-secrets.yaml
```

**Pros:** Centralized secret management, rotation support
**Cons:** Most complex setup, requires external secret manager

---

## Security Best Practices

1. **Never commit `secret.yaml` or `values.yaml` with real secrets**
   ```bash
   echo "secret.yaml" >> .gitignore
   echo "values.secret.yaml" >> .gitignore
   ```

2. **Use RBAC** to limit who can read secrets
   ```bash
   kubectl create role secret-reader --verb=get --resource=secrets
   ```

3. **Rotate tokens regularly** - Update your claiming tokens periodically

4. **Use namespaces** - Isolate Netdata in its own namespace
   ```bash
   kubectl create namespace monitoring
   helm install netdata netdata/netdata -n monitoring -f values.yaml
   ```

5. **Enable audit logging** - Track who accesses secrets in your cluster

---

## Verification

After installation, verify Netdata is running and claimed:

```bash
# Check pod status
kubectl get pods -l app=netdata

# Check logs for claiming success
kubectl logs -l app=netdata --tail=50 | grep -i claim

# Check if secrets are mounted correctly
kubectl describe pod -l app=netdata | grep -A 10 Environment
```

## Troubleshooting

### Claiming fails
- Verify token is correct in secret
- Check network connectivity to Netdata Cloud
- Review logs: `kubectl logs -l app=netdata`

### Secret not found
- Ensure secret exists: `kubectl get secret netdata-claiming`
- Check namespace matches: secrets and pods must be in same namespace

### Permission denied
- Verify RBAC allows pod to read secrets
- Check ServiceAccount has proper permissions
