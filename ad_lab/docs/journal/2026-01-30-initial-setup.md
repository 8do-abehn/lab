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
| 1006 | WS03 | Win11 LTSC | 4GB | 60GB | DHCP | Joined |
| 1007 | LINUX01 | Ubuntu 24.04 | 2GB | 40GB | DHCP | Domain joined |

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

### Completed (Session 2)
- DHCP failover between DC01 and DC02 configured
- LINUX01 joined to domain using SSSD/realmd
- RSAT tools installed on WS01

### Lessons Learned

**DNS Forwarders are critical**
- VLAN 50 needed a DNS forwarder on the UniFi gateway (10.150.50.1)
- Without forwarders, internal DNS worked but external resolution failed
- Symptom: google.com resolved, microsoft.com didn't (microsoft uses stricter DNS/cert validation)
- Error 0x80072f8f on Windows Update = certificate/DNS issue, not actually time

**DHCP Failover gotcha**
- Both DCs must be authorized in AD before failover will work
- DHCP service must be running on partner before creating relationship
- `Get-DhcpServerInDC` to verify authorization status

**Linux AD join (Ubuntu 24.04)**
- Packages: `sssd-ad sssd-tools realmd adcli krb5-user samba-common-bin`
- Kerberos realm must be UPPERCASE: `LAB.LOCAL`
- Minimal Ubuntu installs need `libpam-runtime` for `pam-auth-update`
- Enable home dirs: `echo "session required pam_mkhomedir.so" >> /etc/pam.d/common-session`

**Proxmox/LVM limitations**
- sda4tb (LVM) doesn't support live snapshots - need LVM-thin or ZFS
- Issue #170 created to investigate options

**Windows 11 OOBE annoyances**
- Security questions required for local accounts (just put garbage answers)
- "Domain join instead" skips Microsoft account requirement

### Next Steps
- Phase 3: OU structure, users, groups (#133-137)
- Phase 4: Group Policy basics
- Phase 5+: Security hardening, LAPS, file services
