# Active Directory Lab - Detailed Lesson Plan

This document provides step-by-step tasks for each phase of the AD lab project. Each task is designed to be tracked as a GitHub Issue.

---

## Phase 1: Lab Infrastructure

**Goal**: Set up the Proxmox environment and deploy base VMs

### Tasks

#### 1.1 Proxmox Preparation
- [x] Create dedicated network bridge for AD lab (`vmbr1` with VLAN 50, `10.150.50.0/24`)
- [ ] Upload Windows Server 2025 Eval ISO to Proxmox storage
- [ ] Upload Windows 11 Enterprise Eval ISO to Proxmox storage
- [ ] Upload Ubuntu 24.04 LTS ISO to Proxmox storage
- [ ] Document network topology and IP assignments

#### 1.2 Domain Controller VMs
- [ ] Create DC01 VM (2 vCPU, 4GB RAM, 60GB disk)
- [ ] Install Windows Server 2025 on DC01 (Desktop Experience)
- [ ] Configure static IP for DC01 (`10.150.50.10`)
- [ ] Create DC02 VM with same specs
- [ ] Install Windows Server 2025 on DC02
- [ ] Configure static IP for DC02 (`10.150.50.11`)

#### 1.3 Member Server VM
- [ ] Create FS01 VM (2 vCPU, 4GB RAM, 60GB + 100GB disks)
- [ ] Install Windows Server 2025 on FS01
- [ ] Configure static IP for FS01 (`10.150.50.20`)

#### 1.4 Client VMs
- [ ] Create WS01 VM (Tier 0 PAW) - 2 vCPU, 4GB RAM, 60GB
- [ ] Create WS02 VM (Helpdesk) - 2 vCPU, 4GB RAM, 60GB
- [ ] Create WS03 VM (End User) - 2 vCPU, 4GB RAM, 60GB
- [ ] Install Windows 11 Enterprise on all client VMs
- [ ] Create LINUX01 VM - 2 vCPU, 2GB RAM, 40GB
- [ ] Install Ubuntu 24.04 LTS Server on LINUX01

#### 1.5 Initial Configuration
- [ ] Set hostnames on all VMs
- [ ] Verify network connectivity between all VMs
- [ ] Configure Windows Updates (or disable for lab stability)
- [ ] Take Proxmox snapshots of all fresh installs

**Checkpoint**: All VMs running, networked, and snapshotted

---

## Phase 2: AD DS Foundation

**Goal**: Install and configure Active Directory Domain Services

### Tasks

#### 2.1 DNS Preparation
- [ ] Install DNS Server role on DC01
- [ ] Create forward lookup zone for `lab.local`
- [ ] Create reverse lookup zone for `10.150.50.x`
- [ ] Configure DC01 to use itself for DNS (`127.0.0.1`)
- [ ] Test DNS resolution with `nslookup`

#### 2.2 AD DS Installation on DC01
- [ ] Install AD DS role on DC01
- [ ] Promote DC01 to domain controller
  - New forest: `lab.local`
  - Forest functional level: Windows Server 2025
  - Domain functional level: Windows Server 2025
  - Install DNS (integrated)
  - Set DSRM password (document securely!)
- [ ] Verify AD DS installation with `dcdiag`
- [ ] Verify DNS SRV records created (`_ldap._tcp.lab.local`)

#### 2.3 AD DS Replication (DC02)
- [ ] Point DC02 DNS to DC01 (`10.150.50.10`)
- [ ] Install AD DS role on DC02
- [ ] Promote DC02 as additional domain controller
- [ ] Verify replication with `repadmin /replsummary`
- [ ] Verify both DCs appear in AD Sites and Services
- [ ] Test DNS redundancy (both DCs should resolve domain)

#### 2.4 DHCP Configuration
- [ ] Install DHCP role on DC01
- [ ] Create DHCP scope for lab (`10.150.50.100-200`)
- [ ] Configure scope options:
  - Router: `10.150.50.1` (or your gateway)
  - DNS Servers: `10.150.50.10, 10.150.50.11`
  - Domain Name: `lab.local`
- [ ] Authorize DHCP server in AD
- [ ] Test DHCP lease on a client

#### 2.5 Domain Join Initial Clients
- [ ] Configure WS01 DNS to point to DC01
- [ ] Join WS01 to `lab.local` domain
- [ ] Verify WS01 computer object appears in AD
- [ ] Repeat for WS02 and WS03
- [ ] Install RSAT tools on WS01 (admin workstation)

**Checkpoint**: Two-DC domain running, replicating, clients joined

---

## Phase 3: Users, Groups & OUs

**Goal**: Design and implement organizational structure

### Tasks

#### 3.1 OU Structure Design
- [ ] Plan OU hierarchy (document in `docs/`)
- [ ] Create top-level OUs:
  - `OU=LAB,DC=lab,DC=local` (root for all custom objects)
  - `OU=Admins,OU=LAB,...`
  - `OU=Users,OU=LAB,...`
  - `OU=Workstations,OU=LAB,...`
  - `OU=Servers,OU=LAB,...`
  - `OU=Groups,OU=LAB,...`
  - `OU=Service Accounts,OU=LAB,...`

#### 3.2 Tiered OU Structure
- [ ] Create Tier 0 sub-OUs (Domain Admin level)
  - `OU=Tier 0,OU=Admins,OU=LAB,...`
  - `OU=Tier 0,OU=Workstations,OU=LAB,...` (for PAWs)
- [ ] Create Tier 1 sub-OUs (Server Admin level)
  - `OU=Tier 1,OU=Admins,OU=LAB,...`
- [ ] Create Tier 2 sub-OUs (Workstation Admin level)
  - `OU=Tier 2,OU=Admins,OU=LAB,...`
  - `OU=Helpdesk,OU=Workstations,OU=LAB,...`
- [ ] Create standard user OUs
  - `OU=Standard,OU=Users,OU=LAB,...`

#### 3.3 Security Groups
- [ ] Create Tier 0 groups:
  - `SG-Tier0-Admins` (Domain Admins equivalent)
  - `SG-Tier0-PAW-Users` (can log into Tier 0 PAWs)
- [ ] Create Tier 1 groups:
  - `SG-Tier1-ServerAdmins`
  - `SG-Tier1-PAW-Users`
- [ ] Create Tier 2 groups:
  - `SG-Tier2-WorkstationAdmins`
  - `SG-Helpdesk`
- [ ] Create standard groups:
  - `SG-AllEmployees`
  - `SG-RemoteWorkers`
  - `SG-DepartmentX` (example department groups)

#### 3.4 User Accounts
- [ ] Create Tier 0 admin accounts:
  - `t0-yourname` (your Tier 0 admin)
  - Use strong unique password
  - Add to `SG-Tier0-Admins`
- [ ] Create Tier 1 admin accounts:
  - `t1-yourname` (server admin)
- [ ] Create Tier 2 admin accounts:
  - `t2-yourname` (workstation admin)
- [ ] Create standard user accounts:
  - `user1`, `user2`, `user3` (test users)
- [ ] Create service accounts in Service Accounts OU:
  - `svc-backup`, `svc-app1` (examples)

#### 3.5 Move Computer Objects
- [ ] Move WS01 to `Tier 0\Workstations` OU
- [ ] Move WS02 to `Helpdesk\Workstations` OU
- [ ] Move WS03 to standard Workstations OU
- [ ] Move DC01, DC02 to Servers OU (or leave in Domain Controllers)
- [ ] Move FS01 to Servers OU

#### 3.6 Delegation of Control
- [ ] Delegate password reset to Helpdesk group for standard users OU
- [ ] Delegate computer join to Tier 2 admins for Workstations OU
- [ ] Document all delegations

**Checkpoint**: Clean OU structure, tiered accounts, proper group membership

---

## Phase 4: Group Policy Basics

**Goal**: Implement foundational GPOs and understand processing

### Tasks

#### 4.1 GPO Structure Planning
- [ ] Document GPO naming convention (e.g., `POL-Scope-Description`)
- [ ] Plan GPO layering strategy:
  - Domain-level: Security settings that apply everywhere
  - OU-level: Role-specific settings
- [ ] Create `docs/gpo-inventory.md` to track all GPOs

#### 4.2 Domain-Wide Policies
- [ ] Create `POL-Domain-PasswordPolicy`:
  - Minimum password length: 14 characters
  - Password history: 24 passwords
  - Maximum password age: 90 days
  - Complexity requirements: Enabled
- [ ] Create `POL-Domain-AuditPolicy`:
  - Audit logon events: Success, Failure
  - Audit account management: Success, Failure
  - Audit policy change: Success, Failure

#### 4.3 Workstation Policies
- [ ] Create `POL-Workstations-Security`:
  - Disable guest account
  - Rename Administrator account
  - Configure Windows Firewall defaults
  - Disable SMBv1
- [ ] Create `POL-Workstations-Restrictions`:
  - Prevent access to Control Panel (for standard users)
  - Configure Windows Update settings
  - Set screensaver timeout with password

#### 4.4 Server Policies
- [ ] Create `POL-Servers-Security`:
  - Server-specific security settings
  - Restrict local logon to admins only
  - Disable unnecessary services

#### 4.5 Tier 0 PAW Policies
- [ ] Create `POL-Tier0-PAW-Lockdown`:
  - Restrict logon to Tier 0 admins only
  - Block internet access (or heavily restrict)
  - Disable USB storage
  - Enable AppLocker/WDAC (basic rules)

#### 4.6 GPO Troubleshooting Practice
- [ ] Run `gpresult /r` on a workstation to view applied policies
- [ ] Run `gpresult /h report.html` for detailed HTML report
- [ ] Use `rsop.msc` (Resultant Set of Policy) to troubleshoot
- [ ] Practice forcing GP update with `gpupdate /force`
- [ ] Test policy processing order (Local, Site, Domain, OU)

#### 4.7 GPO Backup
- [ ] Export all GPOs using PowerShell:
  ```powershell
  Backup-GPO -All -Path C:\GPOBackups
  ```
- [ ] Commit GPO exports to `gpos/exports/` in repo

**Checkpoint**: Foundational GPOs applied, understand processing and troubleshooting

---

## Phase 5: Security Hardening

**Goal**: Apply security baselines and harden the environment

### Tasks

#### 5.1 Microsoft Security Baselines
- [ ] Download Windows Server 2025 Security Baseline
- [ ] Download Windows 11 Security Baseline
- [ ] Review baseline documentation
- [ ] Import baselines using LGPO or GPO import
- [ ] Link baselines to appropriate OUs
- [ ] Document any baseline customizations

#### 5.2 Attack Surface Reduction (ASR)
- [ ] Enable ASR rules via GPO:
  - Block Office apps from creating child processes
  - Block credential stealing from LSASS
  - Block untrusted/unsigned processes from USB
- [ ] Configure ASR in audit mode first
- [ ] Review Event Viewer for ASR events
- [ ] Switch to block mode after testing

#### 5.3 Credential Protection
- [ ] Enable Credential Guard on Windows 11 clients
- [ ] Configure Remote Credential Guard
- [ ] Disable WDigest authentication
- [ ] Disable NTLM where possible (start with audit)

#### 5.4 SMB Hardening
- [ ] Disable SMBv1 everywhere (GPO + server features)
- [ ] Require SMB signing
- [ ] Configure SMB encryption where supported

#### 5.5 Administrative Restrictions
- [ ] Block domain admins from logging into workstations
- [ ] Configure "Deny log on locally" for privileged groups
- [ ] Configure "Deny log on through Remote Desktop" appropriately
- [ ] Implement admin account logon restrictions

#### 5.6 Event Log Configuration
- [ ] Increase Security log size (at least 1GB)
- [ ] Enable PowerShell script block logging
- [ ] Enable command line process auditing
- [ ] Configure log forwarding (optional: to central SIEM)

**Checkpoint**: Environment hardened with security baselines

---

## Phase 6: LAPS Implementation

**Goal**: Deploy Local Administrator Password Solution

### Tasks

#### 6.1 Windows LAPS Overview
- [ ] Review Windows LAPS documentation (built into Server 2025/Win11)
- [ ] Understand differences from Legacy LAPS
- [ ] Plan password storage (AD vs Azure AD)

#### 6.2 Schema and Permissions
- [ ] Verify Windows LAPS schema attributes exist
- [ ] Configure computer self-permission to update password
- [ ] Grant read permissions to appropriate admin groups
- [ ] Test permissions with `Get-LapsADPassword`

#### 6.3 GPO Configuration
- [ ] Create `POL-Workstations-LAPS`:
  - Enable LAPS
  - Set password age (30 days)
  - Set password complexity (14+ chars)
  - Configure managed account name
- [ ] Link GPO to workstation OUs
- [ ] Force gpupdate on test workstation

#### 6.4 LAPS Verification
- [ ] Verify password stored in AD:
  ```powershell
  Get-LapsADPassword -Identity WS03 -AsPlainText
  ```
- [ ] Test password rotation
- [ ] Verify Helpdesk can retrieve (Tier 2) workstation passwords
- [ ] Verify Helpdesk cannot retrieve Tier 0 PAW passwords

#### 6.5 LAPS for Servers
- [ ] Create `POL-Servers-LAPS` with server-specific settings
- [ ] Link to Servers OU
- [ ] Verify server passwords are only accessible to Tier 1+

**Checkpoint**: LAPS deployed and verified across all tiers

---

## Phase 7: Tiered Administration Model

**Goal**: Implement complete tier separation

### Tasks

#### 7.1 Tier Model Review
- [ ] Document tier definitions:
  - **Tier 0**: Domain controllers, AD admin accounts
  - **Tier 1**: Member servers, server admin accounts
  - **Tier 2**: Workstations, workstation admin accounts
- [ ] Create architecture diagram

#### 7.2 Authentication Silos (Optional/Advanced)
- [ ] Create authentication policy for Tier 0
- [ ] Create authentication policy silo for DCs
- [ ] Assign Tier 0 admins to silo
- [ ] Test silo enforcement

#### 7.3 Logon Restrictions
- [ ] Create GPO `POL-Tier0-LogonRestrictions`:
  - Allow Tier 0 accounts to log into DCs and Tier 0 PAWs only
  - Deny logon to Tier 1 and Tier 2 systems
- [ ] Create GPO `POL-Tier1-LogonRestrictions`:
  - Allow Tier 1 accounts to log into servers only
  - Deny logon to DCs and workstations
- [ ] Create GPO `POL-Tier2-LogonRestrictions`:
  - Allow Tier 2 accounts to log into workstations only
  - Deny logon to servers and DCs

#### 7.4 PAW Configuration
- [ ] Harden WS01 as Tier 0 PAW:
  - Install only required admin tools
  - Block internet (except to DCs/Azure AD)
  - Enable AppLocker with strict rules
  - Disable unnecessary features
- [ ] Test Tier 0 admin can only use PAW for DC management
- [ ] Test Tier 0 admin cannot log into regular workstations

#### 7.5 Service Account Tiering
- [ ] Review service accounts for tier violations
- [ ] Create separate service accounts per tier
- [ ] Implement Group Managed Service Accounts (gMSA) where possible

#### 7.6 Tier Violation Testing
- [ ] Attempt to log into WS03 with Tier 0 account (should fail)
- [ ] Attempt to log into DC01 with Tier 2 account (should fail)
- [ ] Attempt to log into FS01 with Tier 2 account (should fail)
- [ ] Document all access control tests

**Checkpoint**: Full tier separation implemented and tested

---

## Phase 8: File Services

**Goal**: Configure file server with proper permissions

### Tasks

#### 8.1 File Server Role
- [ ] Install File Server role on FS01
- [ ] Install DFS Namespaces role
- [ ] Install File Server Resource Manager (optional)

#### 8.2 Storage Configuration
- [ ] Initialize 100GB data disk on FS01
- [ ] Format as ReFS or NTFS (document choice)
- [ ] Create folder structure:
  - `D:\Shares\Departments`
  - `D:\Shares\Home`
  - `D:\Shares\Public`

#### 8.3 Share Configuration
- [ ] Create `Departments$` share (hidden)
- [ ] Create `Home$` share for home folders
- [ ] Create `Public` share
- [ ] Configure share permissions (Everyone: Full for shares, restrict via NTFS)

#### 8.4 NTFS Permissions
- [ ] Configure Departments folder permissions by group
- [ ] Set up inheritance properly
- [ ] Test access with different user accounts
- [ ] Document permission structure

#### 8.5 DFS Namespace
- [ ] Create DFS namespace: `\\lab.local\files`
- [ ] Add folder targets for shares
- [ ] Test accessing via DFS path
- [ ] Verify namespace replication (if multiple servers)

#### 8.6 Home Folders (Optional)
- [ ] Configure home folder path in user accounts
- [ ] Set `%username%` substitution
- [ ] Test home folder creation on logon
- [ ] Configure folder redirection GPO (optional)

**Checkpoint**: File server operational with proper permissions

---

## Phase 9: Linux Integration

**Goal**: Join Ubuntu to AD domain

### Tasks

#### 9.1 Linux Preparation
- [ ] Update Ubuntu: `sudo apt update && sudo apt upgrade`
- [ ] Configure static IP or DHCP reservation
- [ ] Set hostname: `sudo hostnamectl set-hostname linux01`
- [ ] Configure DNS to point to DC01
- [ ] Test DNS resolution: `nslookup lab.local`

#### 9.2 Install Required Packages
- [ ] Install SSSD and realmd:
  ```bash
  sudo apt install sssd sssd-tools realmd adcli krb5-user
  ```
- [ ] When prompted for Kerberos realm, enter `LAB.LOCAL`

#### 9.3 Domain Discovery
- [ ] Discover domain: `realm discover lab.local`
- [ ] Review discovered information
- [ ] Verify DNS SRV records are found

#### 9.4 Domain Join
- [ ] Join domain:
  ```bash
  sudo realm join lab.local -U t0-yourname
  ```
- [ ] Verify join: `realm list`
- [ ] Check computer object appears in AD

#### 9.5 SSSD Configuration
- [ ] Review `/etc/sssd/sssd.conf`
- [ ] Configure home directory creation:
  ```
  [domain/lab.local]
  fallback_homedir = /home/%u@%d
  ```
- [ ] Enable mkhomedir PAM module:
  ```bash
  sudo pam-auth-update --enable mkhomedir
  ```
- [ ] Restart SSSD: `sudo systemctl restart sssd`

#### 9.6 Access Control
- [ ] Test login with AD user:
  ```bash
  ssh user1@lab.local@linux01.lab.local
  ```
- [ ] Configure sudo access for AD group:
  ```bash
  echo "%SG-Tier2-WorkstationAdmins@lab.local ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/ad-admins
  ```
- [ ] Test sudo with AD admin account

#### 9.7 GPO for Linux (Optional)
- [ ] Explore ADSys (Canonical's AD GPO for Ubuntu)
- [ ] Or document manual configuration management approach

**Checkpoint**: Linux client joined to domain, AD users can log in

---

## Phase 10: Entra Connect

**Goal**: Set up hybrid identity sync to Microsoft Entra ID

### Tasks

#### 10.1 Azure/Entra Prerequisites
- [ ] Create or access Microsoft 365/Azure tenant
- [ ] Verify Entra ID P1/P2 license (or trial)
- [ ] Create cloud-only Global Admin account (for break-glass)
- [ ] Register custom domain (optional, can use .onmicrosoft.com)

#### 10.2 Entra Connect Preparation
- [ ] Plan sync strategy:
  - Password Hash Sync (PHS) - simplest
  - Pass-through Auth (PTA) - alternative
  - Federation (ADFS) - most complex
- [ ] Decide PHS for this lab
- [ ] Identify OUs to sync (not all OUs!)

#### 10.3 Entra Connect Installation
- [ ] Download Entra Connect on DC02
- [ ] Run installer with Express Settings (for lab) or Custom:
  - Select Password Hash Sync
  - Filter OUs (sync only `LAB` OU, not admin OUs)
  - Do NOT sync Tier 0 admin accounts
- [ ] Complete wizard and verify initial sync

#### 10.4 Verify Sync
- [ ] Check Entra portal for synced users
- [ ] Verify sync status in Entra Connect Health
- [ ] Test sign-in with synced account
- [ ] Check sync errors (if any)

#### 10.5 Sync Filtering
- [ ] Configure OU-based filtering (exclude admin OUs)
- [ ] Configure group-based filtering (optional)
- [ ] Verify filtered objects don't appear in Entra

#### 10.6 Password Writeback (Optional)
- [ ] Enable password writeback in Entra Connect
- [ ] Test password change from cloud
- [ ] Verify change syncs to on-premises AD

**Checkpoint**: Users syncing to Entra ID, can sign in with synced credentials

---

## Phase 11: Hybrid Join

**Goal**: Configure hybrid Azure AD joined devices

### Tasks

#### 11.1 Device Registration Setup
- [ ] Configure SCP (Service Connection Point) in AD
- [ ] Verify SCP: `dsregcmd /status` on workstation
- [ ] Configure Entra Connect for device sync

#### 11.2 GPO for Hybrid Join
- [ ] Create `POL-Workstations-HybridJoin`:
  - Enable automatic device registration
  - Configure device registration settings
- [ ] Link GPO to workstation OUs
- [ ] Force gpupdate and reboot workstation

#### 11.3 Verify Hybrid Join
- [ ] Run `dsregcmd /status` on workstation
- [ ] Verify `AzureAdJoined: YES` and `DomainJoined: YES`
- [ ] Check device appears in Entra ID Devices
- [ ] Verify device shows as Hybrid Azure AD joined

#### 11.4 Troubleshooting
- [ ] Check Event Viewer: `Applications and Services Logs > Microsoft > Windows > User Device Registration`
- [ ] Verify internet connectivity to Azure endpoints
- [ ] Check proxy settings if applicable

#### 11.5 Intune Enrollment (Optional)
- [ ] Configure auto-enrollment via GPO
- [ ] Verify device appears in Intune
- [ ] Test basic Intune policy

**Checkpoint**: Workstations are hybrid joined, appear in Entra ID

---

## Phase 12: Conditional Access

**Goal**: Implement zero-trust access policies

### Tasks

#### 12.1 Conditional Access Planning
- [ ] Document access scenarios:
  - Require MFA for all users
  - Block legacy authentication
  - Require compliant device for sensitive apps
- [ ] Plan named locations (office IPs, VPN)
- [ ] Plan exclusion groups (break-glass accounts)

#### 12.2 MFA Setup
- [ ] Enable Security Defaults OR
- [ ] Configure per-user MFA for test accounts
- [ ] Register MFA methods for test users
- [ ] Test MFA sign-in experience

#### 12.3 Create Conditional Access Policies
- [ ] Create `CA-Require-MFA-AllUsers`:
  - Apply to: All users (exclude break-glass)
  - Cloud apps: All cloud apps
  - Grant: Require MFA
  - Enable in Report-only mode first
- [ ] Create `CA-Block-LegacyAuth`:
  - Apply to: All users
  - Conditions: Client apps = Other clients
  - Grant: Block access
- [ ] Create `CA-Require-CompliantDevice`:
  - Apply to: Selected users/groups
  - Cloud apps: Sensitive apps
  - Grant: Require compliant device

#### 12.4 Testing Conditional Access
- [ ] Test MFA policy with standard user
- [ ] Test legacy auth block (use POP/IMAP client)
- [ ] Test compliant device requirement
- [ ] Review Sign-in logs for policy evaluation

#### 12.5 Refine Policies
- [ ] Move policies from Report-only to Enabled
- [ ] Fine-tune based on test results
- [ ] Document all active policies

#### 12.6 Break-Glass Procedures
- [ ] Document break-glass account usage
- [ ] Configure alerts for break-glass account sign-ins
- [ ] Test break-glass account access

**Checkpoint**: Conditional Access policies protecting cloud resources

---

## Bonus Challenges

After completing all phases, try these additional challenges:

### Challenge 1: Simulate Attack
- [ ] Use tools like BloodHound to map AD
- [ ] Identify potential attack paths
- [ ] Remediate findings

### Challenge 2: Disaster Recovery
- [ ] Simulate DC failure
- [ ] Perform AD authoritative restore
- [ ] Document recovery procedures

### Challenge 3: Certificate Services
- [ ] Install AD Certificate Services
- [ ] Configure certificate templates
- [ ] Deploy certificates via auto-enrollment

### Challenge 4: Azure Arc
- [ ] Enable Azure Arc for on-premises servers
- [ ] Manage servers from Azure portal
- [ ] Apply Azure policies

---

## Resources

### Documentation
- [AD DS Deployment Guide](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/ad-ds-deployment)
- [Microsoft Security Baselines](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines)
- [Windows LAPS](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview)
- [Privileged Access Strategy](https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-strategy)
- [Entra Connect](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-roadmap)
- [Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)

### Tools
- [RSAT (Remote Server Administration Tools)](https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools)
- [BloodHound](https://github.com/BloodHoundAD/BloodHound) - AD attack path mapping
- [PingCastle](https://www.pingcastle.com/) - AD security assessment
- [Purple Knight](https://www.semperis.com/purple-knight/) - AD security assessment
