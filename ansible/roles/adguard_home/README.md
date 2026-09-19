# adguard_home

Deploys and reconciles AdGuard Home.

## Ansible-managed (reconciled on every run, drift is corrected)

- Web UI bind address/port (`adguard_home_web_bind` / `adguard_home_web_port`)
- DNS bind address/port (`adguard_home_dns_bind` / `adguard_home_dns_port`)
- Users / admin password (`adguard_home_username` / `adguard_home_password`)
- DNS rewrites (`adguard_home_rewrites`)
- Blocked services (`adguard_home_blocked_services`)

These are reconciled via the `manage_*.py` scripts in `files/`, which patch
`/opt/AdGuardHome/AdGuardHome.yaml` in place rather than re-templating it, so
fields not listed here are left alone.

## Initial-deploy only (templated once, not reconciled after)

- Upstream/bootstrap DNS (`adguard_home_upstream_dns`, `adguard_home_bootstrap_dns`)
- Conditional forwards (`adguard_home_conditional_forwards`)

These are only written when `AdGuardHome.yaml` doesn't exist yet. If AdGuard's
setup wizard creates the file first, or someone edits these via the UI, a
re-run of this role will not correct them.

## UI-managed (not touched by Ansible at all)

- Query log / stats retention settings
- Custom filter lists added through the UI
- Client-specific settings

Anything in this list can be changed by hand and will survive a re-run of
this role.
