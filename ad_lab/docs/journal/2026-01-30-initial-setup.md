# AD Lab Journal - 2026-01-30

## Initial Infrastructure Setup

### Network Configuration
- Created VLAN 50 (10.150.50.0/24) for AD lab isolation
- Configured on: UniFi SFP-X router, Cisco Business switch, 5-port UniFi switch, Proxmox pve008
- Gateway: 10.150.50.1 (UniFi router handles inter-VLAN routing)
- Created vmbr1 bridge on pve008 with VLAN 50 tag

### ISOs Downloaded
- Windows Server 2025 Evaluation
- Windows 11 Enterprise LTSC Evaluation
- Ubuntu 24.04.3 LTS Server
- VirtIO drivers (required for Windows VMs on Proxmox)

### VMs Created (pve008, sda4tb storage)

| VM ID | Name | OS | RAM | Disk | IP | Status |
|-------|------|-----|-----|------|-----|--------|
| 1001 | DC01 | Server 2025 | 4GB | 60GB | 10.150.50.10 | Domain controller |
| 1002 | DC02 | Server 2025 | 4GB | 60GB | 10.150.50.11 | Domain controller |
| 1003 | FS01 | Server 2025 | 4GB | 60GB + 100GB | 10.150.50.20 | Joined |
| 1004 | WS01 | Win11 LTSC | 4GB | 60GB | DHCP | Joined |
| 1005 | WS02 | Win11 LTSC | 4GB | 60GB | DHCP | Joined |
| 1006 | WS03 | Win11 LTSC | 4GB | 60GB | DHCP | Installing |
| 1007 | LINUX01 | Ubuntu 24.04 | 2GB | 40GB | DHCP | Installing |

### Active Directory Configuration
- Forest: lab.local
- NetBIOS: LAB
- Forest/Domain functional level: WinThreshold (2016+)
- DC01: Primary DC, DNS, DHCP (scope 10.150.50.100-200)
- DC02: Secondary DC, DNS
- DNS configured for redundancy (DCs point to each other first, then localhost)

### Notes
- VirtIO drivers required during Windows install (load from D:\vioscsi\w11\amd64)
- VirtIO network driver installed post-install (D:\NetKVM\w11\amd64)
- QEMU guest agent: D:\guest-agent\qemu-ga-x86_64.msi
- Windows 11 OOBE: Use "Domain join instead" to skip Microsoft account

### Cleanup
- Archived slurm cluster (VMs 200-202 deleted, ansible/k8s configs moved to archive)

### Next Steps
- Complete WS03 and LINUX01 installs
- Take Proxmox snapshots of all VMs
- Phase 3: OU structure, users, groups
- Phase 4: Group Policy basics
