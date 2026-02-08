---
title: "Lab Journal - October 20, 2025: Kubernetes HTTPS, Helm OCI, and the Case of the Missing Secret"
date: 2025-10-20
draft: true
tags: ["proxmox", "ansible", "tailscale", "kubernetes", "containers", "ci-cd"]
---


## Mission: Get Mealie Working and Learn Modern Kubernetes Patterns

Today was a deep dive into modern Kubernetes deployment patterns, HTTPS options for local services, and troubleshooting containerized applications. Started with "why can't I access this in my browser?" and ended with a roadmap for proper TLS setup.

## The Journey

### Act 1: The Browser Security Lockdown

**The Problem:** Mealie was running perfectly on `http://10.150.10.163:9000` but Brave and Edge browsers refused to load it. Safari worked fine.

**The Discovery:** Chromium-based browsers (Brave, Edge) block HTTP on non-localhost IP addresses as a security policy. They've gotten increasingly strict about this - even local network IPs like `10.150.10.x` trigger the block.

**The Realization:** We had two services running:
- `mealie` service on port 9000 ✅ - The actual Mealie application
- `frontend` service on port 8080 ❌ - Unnecessary Apache httpd containers

Mealie v3.x is self-contained! It serves both the web UI and backend API together. The frontend service was just dead weight from testing.

**The Fix Options:**
1. **Quick fix:** `kubectl port-forward -n mealie svc/mealie 9000:9000` - Works with all browsers via localhost
2. **Proper fix:** Enable HTTPS with valid certificates
3. **Current workaround:** Just use Safari for now

### Act 2: The Great HTTPS Debate

Discussed several approaches to get proper HTTPS working:

**Option 1: Tailscale Certificates**
- Tailscale provides automatic HTTPS for machines in your tailnet
- Catch: Only works for actual machines (like `pve001.xxxxts.net`), not arbitrary service names
- Can't just create `mealie.xxxxts.net` without running Tailscale operator

**Option 2: Cloudflare DNS + Origin Certificates** ⭐ *Winner for now*
- Create DNS records in Cloudflare pointing to internal IPs (10.150.10.163)
- Use Cloudflare Origin Certificates on the Ingress controller
- Public DNS but private IPs (resolves publicly but only accessible locally/via VPN)
- Valid HTTPS certificates without exposing services to internet

**Option 3: Cloudflare Tunnel**
- Run `cloudflared` in cluster
- Cloudflare handles TLS automatically
- Access from anywhere (phone while grocery shopping!)
- Maybe later for services that need external access

**Decision:** Going with Cloudflare DNS + Origin Certs for local-only access with valid HTTPS.

### Act 3: The OCI Helm Enlightenment

A philosophical discussion emerged: "What is OCI Helm?"

**Traditional Helm:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-app bitnami/nginx
```

**OCI Helm:**
```bash
helm install my-app oci://registry-1.docker.io/bitnamicharts/nginx
```

**The Key Insight:** OCI Helm stores charts in the same container registries that hold Docker images. Same infrastructure, same security tools, same everything.

**The Learning Question:** "Should I learn traditional Helm first?"

**The Answer:** Not really. OCI is simpler and the future. You'll pick up traditional when you encounter charts that only exist in old-style repos. Don't learn legacy patterns "for completeness" - learn what you need when you need it.

### Act 4: The Homarr Mystery

New deployment, new problem:

```
NAME                      READY   STATUS
homarr-69ffd979dc-plbzn   0/1     CreateContainerConfigError
```

**The Investigation:**
```bash
kubectl describe pod homarr-69ffd979dc-plbzn -n homarr
```

**The Culprit:**
```
Error: secret "db-encryption" not found
```

Homarr needs a secret called `db-encryption` with a key `db-encryption-key` for database encryption. The pod can't start without it.

### Act 5: Declarative vs Imperative - The Eternal Debate

**Imperative (quick and dirty):**
```bash
kubectl create secret generic db-encryption \
  --from-literal=db-encryption-key=$(openssl rand -base64 32) \
  -n homarr
```

**Declarative (the right way):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-encryption
  namespace: homarr
type: Opaque
stringData:
  db-encryption-key: "your-generated-key-here"
```

Using `stringData` is cleaner - Kubernetes automatically base64 encodes it.

**The Important Part:** Don't commit secrets to git in plain text!

**Better Approaches:**
- **Sealed Secrets** - Encrypt secrets that can only be decrypted in-cluster
- **External Secrets Operator** - Pull from Vault/1Password/Bitwarden
- **SOPS** - Encrypt YAML files before committing

### Act 6: The Bitwarden Integration Discovery

Found existing pattern in the repo: `k8s/set-proxmox-creds.sh` already pulls credentials from Bitwarden!

**The Approach:**
1. Store secrets in Bitwarden (password manager)
2. Script pulls from Bitwarden and creates Kubernetes secrets
3. Apply to cluster
4. Secrets never touch git

**The Question:** Should we create a generic script for pulling any K8s secret from Bitwarden?

**Status:** To be continued...

## What We Learned

### Browser Security
- Chromium browsers block HTTP on non-localhost IPs (even local networks)
- Safari is more permissive with local network addresses
- `kubectl port-forward` lets you use `localhost` to bypass browser restrictions

### Kubernetes Service Architecture
- Mealie v3.x is self-contained (UI + API in one container)
- LoadBalancer services working correctly on 10.150.10.163-166
- No need for separate frontend proxies for modern apps

### HTTPS Strategies
- **Tailscale:** Machine-based certs, need operator for per-service names
- **Cloudflare Origin Certs:** Best for local services with valid HTTPS
- **Cloudflare Tunnel:** Best for external access
- Pick the right tool for your access pattern

### Helm Evolution
- OCI Helm is the modern approach (Helm 3.8+, 2022)
- Stores charts in container registries (Docker Hub, GHCR, etc.)
- No separate repo infrastructure needed
- Learn OCI-first, traditional Helm will come naturally

### Kubernetes Secrets
- `stringData` is cleaner than manual base64 encoding
- Never commit secrets to git unencrypted
- Bitwarden integration is a solid pattern
- Declarative YAML > imperative commands for reproducibility

## Current State

**Working:**
- ✅ Mealie accessible via Safari at http://10.150.10.163:9000
- ✅ LoadBalancer service configuration
- ✅ Understanding of HTTPS options
- ✅ Bitwarden secret management pattern established

**In Progress:**
- 🚧 Cloudflare DNS + Origin Certificate setup for Mealie
- 🚧 Homarr db-encryption secret creation
- 🚧 Bitwarden integration for K8s secrets

**Blocked:**
- ⛔ Mealie access from Chromium browsers (waiting on HTTPS)
- ⛔ Homarr pod startup (waiting on secret creation)

## Next Steps

1. **Generate Cloudflare Origin Certificate**
2. **Create Kubernetes TLS Secret** with certificate
3. **Create Ingress resource** for Mealie with TLS
4. **Create Cloudflare DNS A record** pointing to LoadBalancer IP
5. **Create db-encryption secret** for Homarr (via Bitwarden)
6. **Consider:** Generic Bitwarden → K8s secret script

## Technical Artifacts

**Services Running:**
```
mealie namespace:
- mealie (LoadBalancer): 10.150.10.163:9000 → pod:9000
- frontend (LoadBalancer): 10.150.10.163:8080 → pod:8080 (unnecessary)

homarr namespace:
- homarr (pending): waiting for db-encryption secret
```

**Files Referenced:**
- `k8s/set-proxmox-creds.sh` - Bitwarden credential retrieval pattern
- `k8s/deployments/mealie/service.yaml` - Mealie LoadBalancer service
- `k8s/deployments/frontend.yaml` - Unnecessary frontend deployment

## Lessons Learned

1. **Modern apps are self-contained** - Don't assume you need reverse proxies
2. **Browser security evolves** - What worked last year might not work now
3. **OCI is the future** - No need to master legacy patterns first
4. **Secrets need a strategy** - Git is not a secret store
5. **Pick HTTPS based on access pattern** - Local-only vs anywhere access
6. **Declarative > imperative** - Reproducibility matters

## Random Insights

- The user has excellent existing patterns (Bitwarden integration)
- Healthy skepticism about learning "the old way first"
- Practical focus: "What do I need to know now?"
- Clear about goals: Local network access with valid certs

## Top 10 New Commands from October 18-20, 2025

### From October 18 (Tailscale CI/CD Adventure)

1. **`tailscale up --advertise-tags=tag:proxmox --ssh`**
   - Apply Tailscale tags while maintaining non-default settings
   - Key learning: Must mention ALL non-default flags when updating

2. **`bw get item "token - terraform-k8s"`**
   - Pull credentials from Bitwarden CLI
   - Combined with `jq` for parsing JSON

3. **`ansible-playbook --check --diff`**
   - Dry-run mode with change preview
   - Safe way to validate before executing

4. **`ANSIBLE_HOST_KEY_CHECKING='False'`**
   - Environment variable for ephemeral CI runners
   - Necessary for GitHub Actions

5. **`ANSIBLE_SSH_ARGS="-o ProxyCommand=none"`**
   - Bypass Tailscale SSH proxy temporarily
   - Useful for bootstrapping tagged systems

### From October 20 (K8s HTTPS, Helm & Secrets)

6. **`kubectl describe pod <pod> -n <namespace>`**
   - Debug CreateContainerConfigError and other failures
   - Shows events and detailed error messages

7. **`kubectl port-forward -n mealie svc/mealie 9000:9000`**
   - Access HTTP services via localhost to bypass browser restrictions
   - Works with all browsers (Chromium won't block localhost)

8. **`openssl rand -base64 32`**
   - Generate cryptographically secure random secrets
   - Used for database encryption keys

9. **`helm install app oci://registry.example.com/chart`**
   - Modern OCI Helm chart installation
   - No `helm repo add` needed

10. **`kubectl logs -n <namespace> deployment/<name> --tail=50`**
    - View application logs directly from deployment
    - Quick troubleshooting without finding pod names

### Honorable Mentions

- **`kubectl get svc -n namespace`** - Check LoadBalancer external IPs
- **`bw unlock --raw`** - Get Bitwarden session token for scripting
- **`curl -s http://IP:PORT`** - Test service connectivity
- **`kubectl create secret generic --from-literal`** - Imperative secret creation

### Command Pattern Progression

**October 18:** Infrastructure as Code + VPN + CI/CD integration
**October 20:** Modern Kubernetes patterns + Secret management + HTTPS strategies

The combination shows progression from infrastructure automation to application deployment with security best practices!

---

*"HTTPS is not a feature, it's a requirement. Even localhost deserves encryption."* - Modern DevOps Wisdom
