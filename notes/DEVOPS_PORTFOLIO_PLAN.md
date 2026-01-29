# DevOps Portfolio Project Plan
## Goal: Land a DevOps/SRE Role by Showcasing Real Skills

**Timeline**: Nov 1 - Nov 14 (2 weeks for core build, then iterate while job hunting)
**Primary Audience**: Hiring managers looking for Vault/Terraform/K8s/Observability skills

---

## The Project: "Production-Ready K8s Platform"

**One-liner**: "Self-healing Kubernetes platform with Vault-backed secrets, full observability, and GitOps deployment - deployed on bare metal Proxmox"

**Why this works**:
- ✅ Shows infrastructure automation (Terraform)
- ✅ Shows security best practices (Vault PKI, secrets management)
- ✅ Shows container orchestration (K8s)
- ✅ Shows observability (Prometheus/Grafana/Loki)
- ✅ Shows CI/CD (GitHub Actions → K8s)
- ✅ Shows bare metal experience (Proxmox, not just cloud)
- ✅ Tells a story you can explain in interviews
- ✅ Uses your ACTUAL skills from LBI

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Proxmox Host                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   K8s Node 1 │  │   K8s Node 2 │  │   K8s Node 3 │      │
│  │  (Control)   │  │   (Worker)   │  │   (Worker)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│  ┌──────┴──────────────────┴──────────────────┴──────┐      │
│  │            Kubernetes Cluster                      │      │
│  │  ┌──────────────────────────────────────────┐     │      │
│  │  │  Vault (secrets, PKI, dynamic creds)     │     │      │
│  │  ├──────────────────────────────────────────┤     │      │
│  │  │  Sample App (injected secrets)           │     │      │
│  │  ├──────────────────────────────────────────┤     │      │
│  │  │  Prometheus + Grafana + Loki             │     │      │
│  │  ├──────────────────────────────────────────┤     │      │
│  │  │  Cert-Manager (Vault PKI integration)    │     │      │
│  │  ├──────────────────────────────────────────┤     │      │
│  │  │  ArgoCD (GitOps deployment)              │     │      │
│  │  └──────────────────────────────────────────┘     │      │
│  └───────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ Terraform provisions everything
         │
    ┌────┴────┐
    │  GitHub │  (IaC repo + GitOps manifests)
    └─────────┘
```

---

## Phase 1: Foundation (Days 1-3)

### Day 1: Infrastructure Setup
**Goal**: Terraform-provisioned K8s cluster on Proxmox

**Tasks**:
1. Create GitHub repo: `homelab-platform`
2. Write Terraform for:
   - 3 Proxmox VMs (1 control, 2 workers)
   - K3s cluster bootstrap
   - Networking setup
3. Document provider configuration
4. Add README with architecture diagram

**Deliverables**:
- `terraform/` directory with modules
- Working K8s cluster
- `terraform apply` → cluster ready in 10 min

**Time**: 6-8 hours

---

### Day 2: Vault Integration
**Goal**: Vault running in K8s with PKI engine configured

**Tasks**:
1. Deploy Vault via Helm (HA mode with Raft storage)
2. Initialize and unseal automation
3. Configure Vault PKI engine:
   - Root CA
   - Intermediate CA
   - Role for cert-manager
4. Set up Kubernetes auth method
5. Create sample secret paths

**Deliverables**:
- Vault running in cluster
- PKI hierarchy established
- K8s service accounts can authenticate

**Time**: 6-8 hours

---

### Day 3: Observability Stack
**Goal**: Full monitoring/logging/alerting

**Tasks**:
1. Deploy kube-prometheus-stack (Prometheus + Grafana + AlertManager)
2. Deploy Loki + Promtail for log aggregation
3. Create custom dashboards:
   - Cluster health
   - Vault metrics
   - Application performance
4. Set up example alerts (high CPU, pod crashes)
5. Document query patterns

**Deliverables**:
- Grafana accessible with dashboards
- Logs searchable in Loki
- Alerts configured

**Time**: 6-8 hours

---

## Phase 2: Application Platform (Days 4-7)

### Day 4: Secrets Management
**Goal**: Demo app with Vault-injected secrets

**Tasks**:
1. Deploy Vault Agent Injector
2. Create sample web app (simple Go/Python API)
3. App reads:
   - Database credentials from Vault (dynamic)
   - API keys from KV store
   - TLS certs from PKI
4. Show secret rotation in action

**Deliverables**:
- App never has hardcoded secrets
- Secrets auto-rotate
- Logs show secret injection

**Time**: 6-8 hours

---

### Day 5: Certificate Management
**Goal**: Automated cert issuance via cert-manager + Vault

**Tasks**:
1. Deploy cert-manager
2. Configure Vault Issuer
3. Create Certificate resources
4. Demo app using Vault-issued TLS certs
5. Set up auto-renewal

**Deliverables**:
- Certs issued from Vault PKI
- Auto-renewal working
- mTLS between services

**Time**: 4-6 hours

---

### Day 6-7: GitOps & CI/CD
**Goal**: GitHub → ArgoCD → K8s deployment pipeline

**Tasks**:
1. Deploy ArgoCD
2. Create second repo: `homelab-apps`
3. Set up GitOps workflow:
   - Push to main → ArgoCD syncs
   - App manifests in Git
   - Automatic rollback on failure
4. GitHub Actions pipeline:
   - Lint Terraform
   - Validate K8s manifests
   - Build container image
   - Update GitOps repo
5. Demo deployment: PR → merge → auto-deploy

**Deliverables**:
- Working GitOps flow
- CI pipeline running
- Deployment history visible

**Time**: 8-10 hours

---

## Phase 3: Production Hardening (Days 8-10)

### Day 8: Security & Compliance
**Goal**: Production-grade security practices

**Tasks**:
1. Network policies (zero-trust)
2. Pod Security Standards enforcement
3. RBAC configuration (least privilege)
4. Vault audit logging
5. OPA/Gatekeeper policies:
   - No privileged containers
   - Resource limits required
   - Image scanning enforcement
6. Document security model

**Deliverables**:
- Security policies enforced
- Audit logs available
- Compliance documentation

**Time**: 6-8 hours

---

### Day 9: Disaster Recovery
**Goal**: Backup, restore, and failover procedures

**Tasks**:
1. Velero for cluster backups
2. Vault backup automation
3. etcd snapshots
4. Document recovery procedures:
   - Total cluster loss
   - Single node failure
   - Vault seal/unseal
5. Test restore process

**Deliverables**:
- Automated backups
- Tested restore procedures
- Runbook documentation

**Time**: 6-8 hours

---

### Day 10: Documentation & Polish
**Goal**: Portfolio-ready presentation

**Tasks**:
1. Comprehensive README:
   - Architecture diagram
   - Quick start guide
   - Component descriptions
   - Troubleshooting
2. Add Makefile for common operations
3. Create demo script
4. Record demo video (5-10 min)
5. Screenshots of:
   - Grafana dashboards
   - ArgoCD deployment
   - Vault UI
   - GitOps workflow

**Deliverables**:
- Professional documentation
- Demo video
- Easy to reproduce

**Time**: 6-8 hours

---

## Phase 4: Content Creation (Days 11-14)

### Blog Posts (Write These While Job Hunting)

**Post 1: "Building a Production K8s Platform from Scratch"**
- Why K3s on bare metal vs cloud
- Terraform automation approach
- Lessons learned
- **Target**: 1500-2000 words
- **Audience**: DevOps engineers

**Post 2: "Vault-Native Kubernetes: Zero Hardcoded Secrets"**
- Vault Agent Injector deep dive
- PKI integration with cert-manager
- Dynamic database credentials
- Secret rotation strategies
- **Target**: 2000-2500 words
- **Audience**: Security-conscious DevOps teams

**Post 3: "GitOps at Home: ArgoCD + GitHub Actions"**
- Why GitOps matters
- ArgoCD setup and patterns
- CI/CD pipeline design
- Deployment strategies (blue/green, canary)
- **Target**: 1500-2000 words
- **Audience**: Platform engineers

**Optional Post 4: "Observability on a Budget"**
- Prometheus + Grafana + Loki setup
- Custom metrics and dashboards
- Alerting best practices
- **Target**: 1500 words
- **Audience**: SRE teams

**Time**: 2-3 hours per post

---

## Tech Stack Summary

| Category | Technology | Why |
|----------|-----------|-----|
| **Infrastructure** | Proxmox/KVM | Bare metal experience |
| **Provisioning** | Terraform | IaC standard |
| **Orchestration** | K3s (Kubernetes) | Industry standard |
| **Secrets** | HashiCorp Vault | Your core expertise |
| **GitOps** | ArgoCD | Modern deployment |
| **CI/CD** | GitHub Actions | Free, integrated |
| **Monitoring** | Prometheus/Grafana | Industry standard |
| **Logging** | Loki + Promtail | Complements Prometheus |
| **Certificates** | cert-manager + Vault | Automated PKI |
| **Security** | OPA/Gatekeeper | Policy enforcement |
| **Backup** | Velero | K8s-native backup |

---

## Interview Talking Points

### "Walk me through your recent project"

**Your Answer**:
> "I built a production-ready Kubernetes platform on bare metal to showcase modern DevOps practices. It's fully automated with Terraform, uses Vault for zero-trust secrets management, and implements GitOps with ArgoCD.
>
> The interesting challenge was integrating Vault's PKI engine with cert-manager for automated certificate issuance - similar to what I did at LBI but more comprehensive. I also added full observability with Prometheus and Loki, which gave me great insights during testing.
>
> Everything is infrastructure-as-code, so I can destroy and rebuild the entire platform in under 15 minutes. That was important because it let me test disaster recovery procedures realistically."

### "Tell me about a time you solved a complex infrastructure problem"

**Your Answer**:
> "In this project, I needed to solve Vault's chicken-and-egg problem - Kubernetes pods need Vault for secrets, but Vault needs to run in Kubernetes.
>
> I implemented a multi-stage bootstrap: Terraform creates an external Vault seal key in KMS, initializes Vault with auto-unseal, configures the Kubernetes auth backend, then uses Vault Agent Injector for workload secrets. This mirrors production patterns and ensures Vault availability doesn't block the cluster.
>
> At LBI, I used a similar approach for our game dev infrastructure, where build systems needed secrets before the platform was fully online."

### "What's your experience with observability?"

**Your Answer**:
> "I'm a big believer in instrumentation-first development. In my homelab project, I integrated Prometheus, Grafana, and Loki from day one - not as an afterthought.
>
> I created dashboards that track not just cluster health, but application-specific metrics like Vault seal status, secret rotation events, and cert-manager issuance rates. When something breaks, I want telemetry that tells me why, not just that it's broken.
>
> At LBI, I ran Splunk for a multi-region game infrastructure, which taught me the value of structured logging and indexed fields for quick troubleshooting."

---

## Repository Structure

```
homelab-platform/
├── README.md                          # Main documentation
├── docs/
│   ├── ARCHITECTURE.md                # Detailed design
│   ├── DISASTER_RECOVERY.md           # DR procedures
│   ├── SECURITY.md                    # Security model
│   └── TROUBLESHOOTING.md             # Common issues
├── terraform/
│   ├── modules/
│   │   ├── proxmox-vm/                # VM provisioning
│   │   ├── k3s-cluster/               # K8s bootstrap
│   │   └── vault-init/                # Vault initialization
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/
│   ├── bootstrap/                     # Initial cluster setup
│   │   ├── vault/
│   │   ├── cert-manager/
│   │   └── argocd/
│   └── apps/                          # Managed by ArgoCD
├── scripts/
│   ├── backup.sh                      # Backup automation
│   ├── restore.sh                     # Restore procedures
│   └── demo.sh                        # Live demo script
├── .github/
│   └── workflows/
│       ├── terraform-validate.yml
│       └── k8s-lint.yml
└── Makefile                           # Common operations
```

---

## GitHub README Template

```markdown
# Production-Ready Kubernetes Platform

> A fully automated, security-focused Kubernetes platform showcasing modern DevOps practices

![Architecture Diagram](docs/images/architecture.png)

## 🎯 Project Goals

Demonstrate production-grade infrastructure patterns:
- **Zero-Trust Secrets**: HashiCorp Vault with PKI integration
- **Infrastructure as Code**: 100% Terraform-managed
- **GitOps Deployment**: ArgoCD for declarative deployments
- **Full Observability**: Prometheus, Grafana, and Loki
- **Security First**: Network policies, RBAC, pod security standards

## 🚀 Quick Start

```bash
# Clone and deploy
git clone https://github.com/8do-abehn/homelab-platform
cd homelab-platform
make deploy

# Access services
make urls
```

Complete platform deployed in ~10 minutes.

## 📊 What's Inside

- **3-node K3s cluster** on Proxmox (1 control, 2 workers)
- **Vault HA** with Raft storage and auto-unseal
- **ArgoCD** managing all workloads via GitOps
- **Full monitoring stack** (Prometheus/Grafana/Loki)
- **Automated PKI** via cert-manager + Vault
- **Sample application** with injected secrets

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Infrastructure | Proxmox, Terraform |
| Orchestration | Kubernetes (K3s) |
| Secrets | HashiCorp Vault |
| GitOps | ArgoCD |
| Observability | Prometheus, Grafana, Loki |
| CI/CD | GitHub Actions |
| Security | OPA Gatekeeper, Network Policies |

## 📖 Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Security Model](docs/SECURITY.md)
- [Disaster Recovery](docs/DISASTER_RECOVERY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## 🎬 Demo Video

[Watch 5-minute walkthrough](https://youtube.com/...)

## 📝 Blog Series

I wrote about building this:
1. [Production K8s from Scratch](#)
2. [Vault-Native Kubernetes](#)
3. [GitOps at Home](#)

## 🤝 About

Built by [Adam Behn](https://linkedin.com/in/...) to showcase DevOps/SRE skills:
- 3 years managing infrastructure for AAA game development
- HashiCorp Vault expert (secrets, PKI, dynamic credentials)
- Kubernetes, Terraform, CI/CD, Observability
- Former DevOps Manager at Lost Boys Interactive

**Looking for DevOps/SRE opportunities** - [adam@8devops.com](mailto:adam@8devops.com)
```

---

## LinkedIn Strategy

### Post 1: Project Launch (Week 1)
```
I just built a production-ready Kubernetes platform to stay sharp during my job search.

Tech stack: Terraform, Vault, K3s, ArgoCD, Prometheus/Grafana

What made it interesting:
• Zero hardcoded secrets (Vault everywhere)
• GitOps with ArgoCD
• Full disaster recovery automation
• Deployed on bare metal (Proxmox), not cloud

Everything's open source: [github link]

If your team needs a DevOps engineer who ships production-grade infrastructure, let's talk.

#DevOps #Kubernetes #Vault #Terraform #GitOps
```

### Post 2: Blog Post Release (Week 2)
```
I wrote about building Vault-native Kubernetes - zero secrets in code, fully automated PKI, dynamic credentials.

Covers:
→ Vault Agent Injector patterns
→ cert-manager + Vault PKI integration
→ Secret rotation strategies
→ Production gotchas

Based on real patterns from managing infrastructure for AAA game development.

[blog link]

#HashiCorp #Vault #Kubernetes #Security
```

### Post 3: Specific Technical Insight (Week 3)
```
TIL: cert-manager + Vault PKI = automated certificate nirvana

No more manual cert renewals. No more expired certs at 3am.

Setup once, certificates issue/renew automatically from your Vault PKI.

Wrote about it: [link]

What's your cert management strategy?

#DevOps #PKI #Vault
```

---

## Timeline: First 2 Weeks

| Days | Phase | Output |
|------|-------|--------|
| **1-3** | Foundation | Working cluster + Vault + Observability |
| **4-7** | Platform | Secrets injection + Certs + GitOps |
| **8-10** | Hardening | Security + DR + Docs |
| **11-14** | Content | Blog posts + LinkedIn + Demo video |

**Week 3+**: Apply to jobs, continue blogging, refine project based on feedback

---

## Success Metrics

### Portfolio Quality
- ✅ GitHub stars/forks (social proof)
- ✅ Professional documentation
- ✅ Working demo (not just code)
- ✅ Blog posts with engagement

### Job Search Impact
- ✅ Mentioned in 100% of interviews
- ✅ Technical screeners impressed
- ✅ Distinguishes you from other candidates
- ✅ Leads to deeper technical discussions

### Skill Demonstration
- ✅ Shows Vault expertise (your differentiator)
- ✅ Shows infrastructure automation
- ✅ Shows security consciousness
- ✅ Shows production thinking (DR, observability)

---

## Why This Works

**For Hiring Managers**:
1. Demonstrates skills they need
2. Shows initiative and learning
3. Proves you can deliver complete solutions
4. Easy to understand and verify

**For You**:
1. Uses skills you already have
2. Creates talking points for interviews
3. Generates content for LinkedIn/blog
4. Can run demos in technical interviews
5. Shows you think about production concerns

**For Recruiters**:
1. Keywords they search for (Vault, K8s, Terraform)
2. Public GitHub repo they can share
3. Blog posts establish expertise
4. Clear demonstration of experience level

---

## Optional Extensions (If Time Allows)

### Week 3-4: Advanced Features
- **Service Mesh**: Istio/Linkerd for traffic management
- **Policy as Code**: Full OPA policy suite
- **Multi-Tenancy**: Namespaces with Vault namespace delegation
- **Cost Tracking**: Kubecost or custom metrics
- **Chaos Engineering**: Chaos Mesh for resilience testing

### Continuous Content
- **Weekly tips** on LinkedIn (screenshots, quick wins)
- **Twitter/X presence** engaging with DevOps community
- **Answer questions** on Reddit r/devops, r/kubernetes
- **YouTube shorts** of specific features
- **Contribute** to tools you use (file issues, submit PRs)

---

## Budget: $0

Everything runs on hardware you already have:
- ✅ Proxmox host (you have this)
- ✅ Free GitHub
- ✅ Free Terraform
- ✅ Free K8s (K3s)
- ✅ Free monitoring tools
- ✅ Free blog platform (Medium/Dev.to/Hugo on GitHub Pages)

No cloud costs. No subscriptions.

---

## The Bottom Line

**This project positions you as**:
- A Vault expert (your unique skill)
- A production-focused engineer (not just tutorials)
- Someone who automates everything (IaC mindset)
- A security-conscious operator (zero-trust, PKI)
- A communicator (blogs, docs)

**Interview impact**:
- "Show me something you built" → You have a complete platform
- "Explain Vault" → You have a working implementation
- "How do you approach security?" → You have documented practices
- "Tell me about your blog" → You have content

**Two weeks to build. Pays dividends for months.**

Start Day 1 (Nov 1) when furlough begins. By Nov 14, you have a portfolio that sets you apart from 90% of DevOps candidates.

---

## Next Steps

1. **Review this plan** - Any questions/concerns?
2. **Set up GitHub repo** - Create `homelab-platform` (public)
3. **Verify Proxmox access** - Can you spin up 3 VMs?
4. **Start Day 1** - Terraform skeleton + README
5. **Daily commits** - Show consistent progress
6. **Share early** - Post on LinkedIn when 50% done

Want me to help with any specific phase in detail?
