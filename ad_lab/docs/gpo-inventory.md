# GPO Inventory

## Naming Convention

Format: `POL-<Scope>-<Description>`

| Prefix | Scope | Example |
|--------|-------|---------|
| POL-Domain | Domain-wide policies | POL-Domain-PasswordPolicy |
| POL-Workstations | All workstations | POL-Workstations-Security |
| POL-Servers | Member servers | POL-Servers-Security |
| POL-Tier0 | Tier 0 systems (DCs, PAWs) | POL-Tier0-PAW-Lockdown |
| POL-Tier1 | Tier 1 systems (servers) | POL-Tier1-LogonRestrictions |
| POL-Tier2 | Tier 2 systems (workstations) | POL-Tier2-LogonRestrictions |

## GPO List

| GPO Name | Linked To | Purpose | Created |
|----------|-----------|---------|---------|
| POL-Domain-PasswordPolicy | lab.local | Password complexity, length, history | 2026-01-31 |
| POL-Domain-AuditPolicy | lab.local | Security event auditing | 2026-01-31 |
| POL-Workstations-Security | lab.local | Guest disabled, admin renamed | 2026-01-31 |
| POL-Workstations-Restrictions | lab.local | Screensaver, control panel restrictions | 2026-01-31 |
| POL-Tier0-PAW-Lockdown | OU=Tier 0 PAW,OU=Workstations,OU=LAB | Tier 0 logon restriction, USB disabled | 2026-01-31 |
| MSFT-Windows11-Security-Baseline | OU=Workstations,OU=LAB | Microsoft security baseline for Win11 | 2026-01-31 |
| MSFT-Server2025-DC-Baseline | OU=Domain Controllers | Microsoft security baseline for DCs | 2026-01-31 |
| MSFT-Server2025-MemberServer-Baseline | OU=Servers,OU=LAB | Microsoft security baseline for member servers | 2026-01-31 |
| MSFT-DefenderAV-Baseline | lab.local | Microsoft Defender Antivirus baseline | 2026-01-31 |
| POL-Workstations-ASR | OU=Workstations,OU=LAB | Attack Surface Reduction rules (audit mode) | 2026-01-31 |
| POL-Domain-CredentialProtection | lab.local | WDigest disabled, NTLM audit, SMB signing/encryption | 2026-01-31 |
| POL-Domain-Logging | lab.local | 1GB security log, PowerShell logging, cmd line auditing | 2026-01-31 |

## TODO / Skipped

- **POL-Tier0-PAW-Lockdown**: Internet blocking (ports 80/443) not configured - add if needed for production
- **POL-Workstations-ASR**: Rules in Audit mode (value 2) - switch to Block (value 1) after testing
- **POL-Domain-Logging**: Deny logon restrictions deferred to Phase 7 (Tiered Admin Model)

## Notes

- Domain-level GPOs apply to all objects in the domain
- More specific OU-level GPOs override domain settings where applicable
- Test GPOs in Report-only/Audit mode before enforcing
