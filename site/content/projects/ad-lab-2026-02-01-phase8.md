---
title: "AD Lab Journal - 2026-02-01"
date: 2026-02-01
draft: true
tags: ["active-directory"]
---


## Session 5: File Services

### Phase 8: File Services (Completed)

**What we did:**
- Installed File Server, DFS Namespaces, FSRM roles on FS01
- Initialized 100GB data disk as F: drive (NTFS)
- Created folder structure: Departments, Home, Public
- Created SMB shares with proper permissions
- Configured department security groups and NTFS permissions
- Set up DFS namespace: `\\lab.local\Files`
- Configured Folder Redirection GPO for Documents

**Storage Configuration:**
```powershell
Initialize-Disk -Number 1 -PartitionStyle GPT
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter F
Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel "Data"
```
Note: D: and E: were occupied by CD-ROMs, so used F: for data disk.

**Shares Created:**

| Share | Path | Purpose |
|-------|------|---------|
| Departments$ | F:\Shares\Departments | Hidden, department folders |
| Home$ | F:\Shares\Home | Hidden, user home folders |
| Public | F:\Shares\Public | Visible, general access |

**Department Groups & Permissions:**

| Group | Folder | Rights |
|-------|--------|--------|
| SG-Dept-IT | F:\Shares\Departments\IT | Modify |
| SG-Dept-HR | F:\Shares\Departments\HR | Modify |
| SG-Dept-Finance | F:\Shares\Departments\Finance | Modify |

Users added: user1 → IT, user2 → HR, user3 → Finance

**DFS Namespace:**
```
\\lab.local\Files
├── Departments → \\FS01\Departments$
├── Home → \\FS01\Home$
└── Public → \\FS01\Public
```

**Folder Redirection GPO:**
- GPO: `POL-Users-FolderRedirection`
- Linked to: `OU=Users,OU=LAB,DC=lab,DC=local`
- Documents → `\\lab.local\Files\Home\%USERNAME%\Documents`
- Admin access enabled (unchecked "Grant exclusive rights")

### Issues Encountered

**1. DFS Access Denied Initially**
- Symptom: `\\lab.local\Files\Home` access denied via DFS, but `\\FS01\Home$` worked
- Fix: Removed and recreated DFS folder target
- Root cause: Unknown, possibly stale referral

**2. SSH Access - t1-adam Denied**
- t1-adam cannot SSH to FS01, but t0-adam can
- Created issue #180 to investigate
- Likely missing local Administrators group membership

**3. OpenSSH on FS01**
- Enabled SSH for headless management:
  ```powershell
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  Start-Service sshd
  Set-Service -Name sshd -StartupType Automatic
  ```

### Home Folder Permissions (NTFS)

```
F:\Shares\Home
├── SYSTEM: Full Control
├── BUILTIN\Administrators: Full Control
├── LAB\Domain Admins: Full Control
├── LAB\Domain Users: Create Folders (AppendData)
└── CREATOR OWNER: Full Control (inherited to subfolders)
```

Users can access their own folder by path, but cannot list the Home directory.

### Open Issues
- #180 - Review t1-adam SSH access to FS01

### Next Steps
- Phase 9: Linux Integration (mostly complete, needs sudo/access testing)
- Phase 10: Entra Connect (hybrid identity)
