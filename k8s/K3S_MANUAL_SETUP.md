# K3s Cluster Manual Setup Documentation

This documents the manual setup process used to create the k3s cluster in the homelab.

## Overview

The k3s cluster was manually created by cloning the Ubuntu cloud template (VM ID 9000) and then manually installing k3s on each node.

## VM Creation (Proxmox pve007)

### Clone VMs from Template

```bash
# Clone master node
qm clone 9000 301 --name k3s-master-01 --full

# Clone worker nodes
qm clone 9000 401 --name k3s-worker-01 --full
qm clone 9000 402 --name k3s-worker-02 --full
qm clone 9000 403 --name k3s-worker-03 --full

# Start master node
qm start 301
```

**VM IDs:**
- `301` - k3s-master-01 (control plane)
- `401` - k3s-worker-01
- `402` - k3s-worker-02
- `403` - k3s-worker-03

**Template Source:** VM 9000 (ubuntu-cloud-template)

---

## K3s Installation

### Master Node Setup

SSH into the master node and install k3s:

```bash
# Install k3s on master node
curl -sfL https://get.k3s.io | sh -

# Get the node token for worker nodes
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Note:** The node token is required to join worker nodes to the cluster.

### Retrieve Kubeconfig

The kubeconfig is automatically generated at `/etc/rancher/k3s/k3s.yaml`:

```bash
# View kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

**Important:** Copy this kubeconfig to your local machine and update the server address from `127.0.0.1` to the master node's IP/hostname.

### Worker Node Setup

SSH into each worker node and join the cluster:

```bash
# On each worker node
curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master-01:6443 K3S_TOKEN=<node-token> sh -
```

Replace `<node-token>` with the token retrieved from the master node.

---

## Post-Installation Configuration

After the VMs were created and k3s installed, Ansible was used for additional configuration:

```bash
# Install basic tools (vim, git)
ansible-playbook -i inventory/homelab.yml k3s_setup_tools.yml

# Configure Tailscale on k3s nodes
ansible-playbook -i inventory/homelab.yml site.yml --limit k3s_cluster
```

**Ansible Inventory Location:** `ansible/inventory/homelab.yml`

**Group Variables:** `ansible/group_vars/k3s_cluster.yml`
- Tailscale tags: `tag:k3s`

---

## Verification

Verify the cluster is running:

```bash
# On master node
kubectl get nodes

# Expected output:
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-master-01    Ready    control-plane,master   X     v1.xx.x+k3s1
# k3s-worker-01    Ready    <none>                 X     v1.xx.x+k3s1
# k3s-worker-02    Ready    <none>                 X     v1.xx.x+k3s1
# k3s-worker-03    Ready    <none>                 X     v1.xx.x+k3s1
```

---

## Current State

### What's Automated
- ✅ VM template creation (Terraform/Packer - `k8s/terraform/cloud-template.tf`)
- ✅ Post-installation configuration (Ansible - basic tools, Tailscale)

### What's Manual
- ❌ VM cloning from template
- ❌ K3s installation on master
- ❌ K3s worker node joining
- ❌ Kubeconfig retrieval and setup

---

## Future Automation Options

To fully automate this process, consider:

### Option 1: Ansible Playbook
Create an Ansible playbook to handle k3s installation:

```yaml
# ansible/k3s_install.yml
- name: Install k3s on master
  hosts: k3s_master
  become: yes
  tasks:
    - name: Install k3s
      shell: curl -sfL https://get.k3s.io | sh -

- name: Install k3s on workers
  hosts: k3s_workers
  become: yes
  tasks:
    - name: Join k3s cluster
      shell: curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master-01:6443 K3S_TOKEN={{ master_token }} sh -
```

### Option 2: Terraform + Cloud-Init
Extend Terraform to:
1. Clone VMs from template
2. Use cloud-init to run k3s installation on first boot

### Option 3: Packer + K3s Pre-installed
Create a Packer template with k3s pre-installed (though this makes master/worker differentiation harder)

---

## Notes

- The Packer template `k8s/packer/k8s-node.pkr.hcl` exists but installs traditional Kubernetes (kubeadm) not k3s
- The `ansible/roles/k3s/` directory exists but is currently empty
- VM template 9000 is the standard Ubuntu 22.04 cloud-init template

---

## References

- [K3s Quick Start Guide](https://docs.k3s.io/quick-start)
- [K3s Installation Options](https://docs.k3s.io/installation/configuration)
- Proxmox qm commands: `man qm`

---

*Documented from bash history on pve007 and k3s-master-01*
*Date: October 2025*
