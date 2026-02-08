---
title: "AD Lab Journal - 2026-02-01"
date: 2026-02-01
draft: true
tags: ["proxmox", "active-directory"]
---


## Session 6: Entra Connect Setup

### Phase 10: Entra Connect (In Progress)

**Goal:** Set up hybrid identity sync to Microsoft Entra ID

### Key Discovery: Windows Server 2025 Not Supported

Attempted to install Entra Connect on DC02, hit multiple issues:

1. **TLS 1.2 Error** - Fixed with built-in tool:
   ```powershell
   Import-Module "C:\Program Files\Microsoft Azure Active Directory Connect\Tools\ADSyncTools"
   Set-ADSyncToolsTls12 -Enable $true
   ```

2. **BAML/WPF Error** - `System.Windows.Baml2006.TypeConverterMarkupExtension`
   - Root cause: DC02 and FS01 are both **Server Core** (no GUI)
   - Entra Connect requires Desktop Experience

3. **Server 2025 Not Officially Supported**
   - Microsoft docs: "Windows Server 2025 support planned for future release"
   - Both Entra Connect and Cloud Sync have known issues on 2025

### Solution: SYNC01 (Windows Server 2022)

Created dedicated sync server with Desktop Experience:

| Setting | Value |
|---------|-------|
| VM ID | 1008 |
| Name | SYNC01 |
| OS | Windows Server 2022 Eval |
| vCPU | 2 |
| RAM | 4GB |
| Disk | 40GB |
| IP | 10.150.50.12 |
| Network | E1000 (VirtIO driver missing) |

**Setup steps:**
1. Created VM on Proxmox with Server 2022 ISO
2. Installed with **Desktop Experience** (critical)
3. Changed NIC from VirtIO to E1000 (no driver on fresh install)
4. Set static IP, joined to lab.local domain

### Cloud Sync vs Entra Connect

Tried Cloud Sync first (newer, Microsoft's direction):
- Agent installed successfully on SYNC01
- Agent registered in Entra portal
- **Blocked: Requires Entra ID P1 license**

Decision: Use classic Entra Connect (free) or get P1 via M365 Dev Program.

### M365 Developer Program

Signing up for M365 Developer Program to get:
- 25 E5 licenses (includes Entra ID P2)
- 90-day subscription, auto-renews with activity
- Full feature access for Phases 10-12

**Status:** Signup blocked by phone verification (number already used). Retrying tomorrow.

### Licensing Summary

| Tool | License Required |
|------|------------------|
| Entra Connect | Free |
| Entra Cloud Sync | P1 |
| Hybrid Join (Phase 11) | P1 |
| Conditional Access (Phase 12) | P1 |

### Lessons Learned

1. **Check Server Core vs Desktop Experience** before planning installs
2. **Server 2025 is bleeding edge** - not all tools support it yet
3. **Cloud Sync is the future** but requires P1; Entra Connect is free fallback
4. **M365 Dev Program** is the way for lab work - full E5 at no cost

### Next Steps

1. Complete M365 Dev Program signup
2. Optionally move 8devops.com custom domain to new tenant
3. Install Entra Connect on SYNC01 pointing to new tenant
4. Configure sync filtering (exclude admin OUs)
5. Verify users appear in Entra portal

### Open Questions

- Should 8devops.com move to dev tenant or stay on current?
- Sync all users or filter to specific OUs?
