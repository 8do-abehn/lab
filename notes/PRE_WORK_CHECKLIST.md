# Pre-Work Checklist (Before Nov 1)
## Get Everything Ready to Start Day 1 Fast

---

## ✅ Infrastructure Verification (Do This Week)

### Proxmox Access
- [ ] **Verify Proxmox is accessible**
  - URL: `https://<your-proxmox-ip>:8006`
  - Login works
  - Note version number

- [ ] **Configure Tailscale hostname for Proxmox**
  - Set hostname: `tailscale set --hostname pve`
  - Configure pveproxy to accept Tailscale hostname
  - Access via: `https://pve.taile975f.ts.net:8006`
  - See ~/8do/lab/notes/proxmox-tailscale-hostname.md for details

- [ ] **Check available resources**
  - CPU cores available: ____
  - RAM available: ____ GB (need minimum 12GB for 3 VMs)
  - Storage available: ____ GB (need minimum 60GB)
  - Note storage pool name: ____

- [ ] **Test VM creation**
  - Can you create a test VM?
  - Can you delete it?
  - Does Terraform Proxmox provider work with your version?

- [ ] **Network setup**
  - Note bridge name (usually `vmbr0`): ____
  - DHCP available or need static IPs?
  - Firewall rules needed?

### API Access
- [ ] **Create Proxmox API token**
  - Datacenter → Permissions → API Tokens
  - Create token for Terraform
  - Save token ID and secret (will need for Terraform)
  - Test API access:
    ```bash
    curl -k -H "Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET" \
      https://PROXMOX-IP:8006/api2/json/version
    ```

---

## 🔧 Development Environment (Do This Week)

### Required Tools
- [ ] **Terraform installed**
  ```bash
  terraform version
  # Should be v1.5+
  ```
  - If not: https://developer.hashicorp.com/terraform/downloads

- [ ] **kubectl installed**
  ```bash
  kubectl version --client
  ```
  - If not: `sudo snap install kubectl --classic`

- [ ] **helm installed**
  ```bash
  helm version
  ```
  - If not: `sudo snap install helm --classic`

- [ ] **git configured**
  ```bash
  git config --global user.name "Adam Behn"
  git config --global user.email "adam@8devops.com"
  ```

- [ ] **SSH keys ready**
  ```bash
  ls ~/.ssh/id_rsa.pub
  # or
  ls ~/.ssh/id_ed25519.pub
  ```
  - If not: `ssh-keygen -t ed25519 -C "adam@8devops.com"`

### Optional but Recommended
- [ ] **k9s** (K8s TUI)
  ```bash
  sudo snap install k9s
  ```

- [ ] **vault CLI**
  ```bash
  sudo snap install vault
  ```

- [ ] **jq** (JSON parsing)
  ```bash
  sudo apt install jq -y
  ```

---

## 📦 GitHub Setup (Do This Week)

### Create Repository
- [ ] **Create public repo: `homelab-platform`**
  - Go to: https://github.com/new
  - Name: `homelab-platform`
  - Description: "Production-ready Kubernetes platform with Vault, GitOps, and full observability"
  - Public ✓
  - Add README ✓
  - Add .gitignore (Terraform template)
  - License: MIT

- [ ] **Clone locally**
  ```bash
  cd ~/8do
  git clone git@github.com:8do-abehn/homelab-platform.git
  cd homelab-platform
  ```

- [ ] **Initial commit**
  - Add basic README
  - Add .gitignore
  - Commit and push

### GitHub Settings
- [ ] **Enable Issues** (for tracking progress)
- [ ] **Enable Discussions** (optional)
- [ ] **Add topics**: `kubernetes`, `terraform`, `vault`, `gitops`, `devops`, `homelab`

---

## 📖 Research & Reading (Optional - This Week)

### Quick Refreshers
- [ ] Terraform Proxmox Provider docs
  - https://registry.terraform.io/providers/Telmate/proxmox/latest/docs

- [ ] K3s installation
  - https://docs.k3s.io/quick-start

- [ ] Vault on Kubernetes
  - https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide

- [ ] ArgoCD Getting Started
  - https://argo-cd.readthedocs.io/en/stable/getting_started/

### Blog Platform Decision
- [ ] **Choose where to publish blog posts**
  - Option 1: Medium (easy, built-in audience)
  - Option 2: Dev.to (dev-focused, good SEO)
  - Option 3: Hugo on GitHub Pages (full control, more setup)
  - **My recommendation**: Start with Dev.to, migrate to Hugo later

- [ ] **Create account and test post**

---

## 🎯 LinkedIn Prep (Do This Week)

### Profile Updates
- [ ] **Update headline**
  - Current: ?
  - New: "DevOps Engineer | Vault | Kubernetes | Terraform | Open to Work"

- [ ] **Update "Open to Work"**
  - Turn on Open to Work badge
  - Set preferences:
    - Job titles: DevOps Engineer, SRE, Platform Engineer, Infrastructure Engineer
    - Location: Remote, Chippewa Falls WI area
    - Work type: Remote, Hybrid, On-site

- [ ] **Update About section**
  - Mention furlough professionally
  - Highlight Vault expertise
  - Link to GitHub

### Content Prep
- [ ] **Draft announcement post** (will publish Nov 1-3)
  ```
  Starting a new project during my job search: building a production-ready
  K8s platform with Vault, Terraform, and GitOps.

  Following along: [github link]

  #DevOps #Kubernetes #Vault
  ```

- [ ] **Follow key people/companies**
  - HashiCorp
  - CNCF
  - DevOps influencers
  - Target companies

---

## 📋 Day 1 Prep (Do Oct 31)

### Create Project Structure
- [ ] **Directory layout**
  ```bash
  cd ~/8do/homelab-platform
  mkdir -p terraform/modules/{proxmox-vm,k3s-cluster,vault-init}
  mkdir -p kubernetes/{bootstrap,apps}
  mkdir -p docs scripts .github/workflows
  ```

- [ ] **Create initial files**
  ```bash
  touch terraform/main.tf
  touch terraform/variables.tf
  touch terraform/outputs.tf
  touch Makefile
  touch docs/ARCHITECTURE.md
  ```

### Terraform Skeleton
- [ ] **Create `terraform/main.tf` with provider**
  ```hcl
  terraform {
    required_providers {
      proxmox = {
        source  = "telmate/proxmox"
        version = "~> 2.9"
      }
    }
  }

  provider "proxmox" {
    pm_api_url      = var.proxmox_api_url
    pm_api_token_id = var.proxmox_token_id
    pm_api_token_secret = var.proxmox_token_secret
    pm_tls_insecure = true
  }
  ```

- [ ] **Create `terraform/variables.tf`**
  ```hcl
  variable "proxmox_api_url" {
    description = "Proxmox API URL"
    type        = string
  }

  variable "proxmox_token_id" {
    description = "Proxmox API Token ID"
    type        = string
    sensitive   = true
  }

  variable "proxmox_token_secret" {
    description = "Proxmox API Token Secret"
    type        = string
    sensitive   = true
  }
  ```

- [ ] **Create `terraform.tfvars` (gitignored)**
  ```hcl
  proxmox_api_url      = "https://YOUR-IP:8006/api2/json"
  proxmox_token_id     = "YOUR-TOKEN-ID"
  proxmox_token_secret = "YOUR-SECRET"
  ```

- [ ] **Test Terraform**
  ```bash
  cd terraform
  terraform init
  terraform validate
  ```

### Makefile Skeleton
- [ ] **Create basic Makefile**
  ```makefile
  .PHONY: help init plan apply destroy

  help:
  	@echo "homelab-platform - Production K8s Platform"
  	@echo ""
  	@echo "Available commands:"
  	@echo "  make init     - Initialize Terraform"
  	@echo "  make plan     - Terraform plan"
  	@echo "  make apply    - Deploy everything"
  	@echo "  make destroy  - Tear down everything"

  init:
  	cd terraform && terraform init

  plan:
  	cd terraform && terraform plan

  apply:
  	cd terraform && terraform apply

  destroy:
  	cd terraform && terraform destroy
  ```

---

## 🗓️ Nov 1 Schedule (First Day)

### Morning (9am-12pm)
- [ ] 9:00-10:00: Finish Proxmox VM Terraform module
- [ ] 10:00-11:00: Test VM creation/destruction
- [ ] 11:00-12:00: K3s bootstrap script

### Afternoon (1pm-5pm)
- [ ] 1:00-2:30: Deploy 3 VMs with K3s
- [ ] 2:30-3:30: Verify cluster, test kubectl
- [ ] 3:30-5:00: Documentation & commit

### Evening (Optional)
- [ ] Write Day 1 summary
- [ ] LinkedIn post with progress screenshot
- [ ] Plan Day 2

---

## ❓ Questions to Answer Before Nov 1

### Proxmox
- Where is Proxmox running? (IP/hostname): ____
- Do you have API credentials?: ____
- What storage pool will you use?: ____

### Networking
- Will VMs use DHCP or static IPs?: ____
- Any firewall rules needed?: ____
- Can VMs reach internet?: ____

### Time Commitment
- How many hours per day?: ____ (recommended: 6-8 hours)
- What time of day works best?: ____
- Any interruptions/commitments?: ____

### Backup Plan
- Do you have a second machine if Proxmox has issues?: ____
- Could you use cloud VMs if Proxmox fails? (costs $$$): ____

---

## 🚨 Potential Blockers to Solve Now

### If Proxmox isn't available
- **Plan B**: Use Multipass for local VMs
  ```bash
  sudo snap install multipass
  multipass launch --name k3s-test
  ```
- **Plan C**: Use cloud (DigitalOcean, Linode) - costs ~$30/month

### If you don't have 12GB RAM available
- **Option 1**: Single node K3s (1 VM, 4GB RAM)
- **Option 2**: Reduce worker nodes to 1 (2 VMs total)

### If Terraform Proxmox provider doesn't work
- **Plan B**: Manual VM creation + Ansible
- **Plan C**: Use libvirt/KVM instead of Proxmox

---

## ✅ Final Checklist (Oct 31 EOD)

- [ ] Proxmox verified and accessible
- [ ] API tokens created and tested
- [ ] GitHub repo created with initial structure
- [ ] All tools installed (terraform, kubectl, helm)
- [ ] Terraform skeleton tested (`terraform init` works)
- [ ] Day 1 schedule printed/visible
- [ ] LinkedIn post drafted
- [ ] Calendar clear for Nov 1

---

## 📞 Resources & Support

- **Terraform Proxmox Provider**: https://registry.terraform.io/providers/Telmate/proxmox/latest
- **K3s Docs**: https://docs.k3s.io/
- **Vault Docs**: https://developer.hashicorp.com/vault
- **My availability**: Ask me any questions as you go!

---

## 🎯 Success Criteria for Pre-Work

By Oct 31 EOD, you should be able to:
1. ✅ Access Proxmox and create/delete a test VM
2. ✅ Run `terraform init` successfully
3. ✅ Run `make help` in your project
4. ✅ Push initial commit to GitHub
5. ✅ Have a clear schedule for Nov 1

**If you can do all 5 of these, you're ready to start Day 1!**

---

Ready to tackle this list? Let me know if you need help with any specific item!
