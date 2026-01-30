# Active Directory Lab - Skills Refresh Project

A hands-on Active Directory lab environment for refreshing enterprise AD skills, including modern hybrid cloud integration with Microsoft Entra ID.

## Project Goals

- Refresh AD fundamentals after 4-year gap (20+ years prior experience)
- Build a realistic enterprise-like lab environment on Proxmox
- Practice modern security hardening (LAPS, tiered admin, security baselines)
- Implement full hybrid identity with Entra ID and Conditional Access
- Document learnings for future reference

## Lab Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Proxmox Host                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │    DC01      │  │    DC02      │  │   FS01       │                   │
│  │ Win Srv 2025 │  │ Win Srv 2025 │  │ Win Srv 2025 │                   │
│  │              │  │              │  │              │                   │
│  │ - AD DS      │  │ - AD DS      │  │ - File Svcs  │                   │
│  │ - DNS        │  │ - DNS        │  │ - DFS        │                   │
│  │ - DHCP       │  │ - Entra Conn │  │              │                   │
│  │ - GPO Mgmt   │  │ - Backup DC  │  │              │                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │    WS01      │  │    WS02      │  │    WS03      │  │   LINUX01    │ │
│  │  Windows 11  │  │  Windows 11  │  │  Windows 11  │  │ Ubuntu 24.04 │ │
│  │              │  │              │  │              │  │              │ │
│  │ - Tier 0 PAW │  │ - Helpdesk   │  │ - End User   │  │ - SSSD/Realm │ │
│  │ - RSAT Tools │  │ - Limited    │  │ - Standard   │  │ - AD Join    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Entra Connect Sync
                                    ▼
                    ┌───────────────────────────────┐
                    │      Microsoft Entra ID       │
                    │                               │
                    │  - User/Group Sync            │
                    │  - Hybrid Join                │
                    │  - Conditional Access         │
                    │  - MFA                        │
                    └───────────────────────────────┘
```

## VM Specifications

| VM ID | VM | OS | vCPU | RAM | Disk | IP | Role |
|-------|----|----|------|-----|------|----|------|
| 1001 | DC01 | Windows Server 2025 Eval | 2 | 4GB | 60GB | 10.150.50.10 | Primary DC, DNS, DHCP |
| 1002 | DC02 | Windows Server 2025 Eval | 2 | 4GB | 60GB | 10.150.50.11 | Secondary DC, DNS |
| 1003 | FS01 | Windows Server 2025 Eval | 2 | 4GB | 60GB + 100GB | 10.150.50.20 | File Server, DFS |
| 1004 | WS01 | Windows 11 Enterprise LTSC | 2 | 4GB | 60GB | DHCP | Tier 0 PAW |
| 1005 | WS02 | Windows 11 Enterprise LTSC | 2 | 4GB | 60GB | DHCP | Helpdesk workstation |
| 1006 | WS03 | Windows 11 Enterprise LTSC | 2 | 4GB | 60GB | DHCP | End-user workstation |
| 1007 | LINUX01 | Ubuntu 24.04 LTS Server | 2 | 2GB | 40GB | DHCP | Linux AD client |

**Proxmox Host**: pve008
**Storage**: sda4tb
**Total Resources**: 14 vCPU, 26GB RAM, 540GB disk

## Domain Details

- **Domain Name**: `lab.local` (internal) / `yourtenantname.onmicrosoft.com` (Entra)
- **NetBIOS**: `LAB`
- **Forest/Domain Functional Level**: WinThreshold (Server 2016+)
- **Sites**: Single site (Default-First-Site-Name)
- **DHCP Scope**: 10.150.50.100-200

## Prerequisites

### Proxmox Setup
- [x] Proxmox VE 8.x installed and accessible (pve008)
- [x] Sufficient resources (see VM specs above)
- [x] ISO storage configured (local)
- [x] Network bridge configured (vmbr1 on VLAN 50, 10.150.50.0/24)

### Downloads Required
- [x] [Windows Server 2025 Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025)
- [x] [Windows 11 Enterprise LTSC Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise)
- [x] [Ubuntu 24.04 LTS Server ISO](https://ubuntu.com/download/server)
- [x] [VirtIO Drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) - Required for Windows VMs using VirtIO disk/network on Proxmox. Attach as second CD-ROM during install, load driver from `vioscsi\w11\amd64`.

### Cloud Requirements (for hybrid phases)
- [ ] Microsoft 365 tenant (free developer tenant works)
- [ ] Entra ID P1 or P2 license (trial available)
- [ ] Global admin access to tenant

## Project Phases

| Phase | Topic | Milestones |
|-------|-------|------------|
| **1** | Lab Infrastructure | Proxmox VMs, networking, Windows Server install |
| **2** | AD DS Foundation | DNS, AD install, domain structure, replication |
| **3** | Users, Groups & OUs | OU design, user/group creation, delegation |
| **4** | Group Policy Basics | GPO structure, basic policies, troubleshooting |
| **5** | Security Hardening | Security baselines, attack surface reduction |
| **6** | LAPS Implementation | Legacy LAPS and Windows LAPS setup |
| **7** | Tiered Admin Model | PAWs, tier 0/1/2 separation, admin accounts |
| **8** | File Services | File server, shares, DFS, NTFS permissions |
| **9** | Linux Integration | SSSD, realm join, PAM/NSS configuration |
| **10** | Entra Connect | Sync setup, filtering, password hash sync |
| **11** | Hybrid Join | Device registration, hybrid Azure AD join |
| **12** | Conditional Access | MFA, device compliance, access policies |

## Evaluation License Timeline

Windows Server and Windows 11 evaluation licenses are valid for **180 days**. Plan accordingly:

- **Days 1-30**: Phases 1-4 (Foundation)
- **Days 31-60**: Phases 5-7 (Security)
- **Days 61-90**: Phases 8-9 (Services & Linux)
- **Days 91-120**: Phases 10-12 (Cloud Hybrid)
- **Days 121-180**: Practice, break things, rebuild

> **Tip**: You can rearm Windows eval licenses once with `slmgr /rearm`, extending to 360 days total. Use sparingly.

## Resource Management Notes

### Proxmox Host Requirements

**Minimum viable** (run 3-4 VMs concurrently):
- 32GB RAM, 4-core CPU, 500GB SSD
- Start/stop VMs as needed per phase

**Comfortable** (run all 7 VMs):
- 64GB RAM, 8-core CPU, 1TB SSD
- Keep everything running for realistic testing

### Memory Optimization Tips

1. **Stagger VM startup** - DCs first, wait for AD services, then clients
2. **Use Proxmox ballooning** - Set min memory lower than max (e.g., 2GB min / 4GB max)
3. **Shutdown unused VMs** - LINUX01 only needed for Phase 9, FS01 only for Phase 8
4. **Snapshot before experiments** - Cheaper than rebuilding

### Running the Lab from macOS

Since you're on macOS, you'll manage everything remotely:

| Task | Tool |
|------|------|
| Proxmox management | Web UI (https://proxmox:8006) |
| Windows Server RDP | Microsoft Remote Desktop app |
| PowerShell remoting | `Enter-PSSession` from PowerShell 7 |
| SSH to Linux | Terminal or iTerm2 |
| AD management | RSAT via RDP to WS01, or Windows Admin Center |

**Recommended**: Install [Royal TSX](https://royalapps.com/ts/mac/features) or similar for managing multiple RDP/SSH sessions.

### Cloud Cost Considerations

The hybrid phases (10-12) require Azure/Entra resources:

| Resource | Cost | Notes |
|----------|------|-------|
| Entra ID P1 | ~$6/user/month | Required for Conditional Access |
| Entra ID P2 | ~$9/user/month | Adds PIM, risk-based CA (optional) |
| M365 Developer Tenant | Free | 25 E5 licenses for 90 days, renewable |

**Recommendation**: Use the [M365 Developer Program](https://developer.microsoft.com/en-us/microsoft-365/dev-program) for a free tenant with E5 licenses. Renews automatically if you show development activity.

### Pacing Suggestions

**Aggressive (weekends only, ~2 months)**:
- 1 phase per weekend
- Focus on hands-on, skip deep documentation

**Steady (evenings, ~3 months)**:
- 2-3 tasks per session
- Document as you go, build muscle memory

**Thorough (no rush, ~4-6 months)**:
- Deep dive each phase
- Write scripts to automate everything
- Break and rebuild multiple times

### Snapshot Strategy

Take Proxmox snapshots at these key points:

1. **After Phase 1** - Clean OS installs (before any config)
2. **After Phase 2** - Working domain with replication
3. **After Phase 4** - Base GPOs applied
4. **After Phase 7** - Full tiered model (good restore point)
5. **Before Phase 10** - Pre-cloud baseline

Label snapshots clearly: `phase2-domain-working-2024-01-29`

## File Structure

```
ad_lab/
├── README.md                 # This file (PRD)
├── LESSON_PLAN.md           # Detailed lesson plan with tasks
├── docs/
│   ├── phase-01-infrastructure.md
│   ├── phase-02-adds-foundation.md
│   └── ...
├── scripts/
│   ├── powershell/          # AD automation scripts
│   └── bash/                # Linux integration scripts
├── gpos/
│   └── exports/             # GPO backup exports
└── templates/
    └── proxmox/             # VM templates/cloud-init configs
```

## Quick Links

- [Detailed Lesson Plan](LESSON_PLAN.md)
- [Microsoft Eval Center](https://www.microsoft.com/en-us/evalcenter/)
- [Entra ID Free Tier](https://azure.microsoft.com/en-us/pricing/details/active-directory/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [Microsoft Security Baselines](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines)

## Progress Tracking

Progress is tracked via GitHub Issues and Milestones. Each phase has a corresponding milestone with individual tasks as issues.

View progress: [GitHub Issues](../../issues?q=label%3Aad-lab)
