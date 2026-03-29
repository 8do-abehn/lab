# Lab Repo

## Repo Structure
- `ansible/` — Ansible playbooks and roles for Proxmox homelab
- `site/` — Hugo blog (lab.8devops.com) with PaperMod theme (submodule)
- `scripts/` — migrate-content.sh (restores from v1-archive), audit-content.sh (PII scanner)
- `.github/workflows/` — ansible-ci, ansible-deploy, deploy-blog, gitleaks
- `.githooks/pre-commit` — gitleaks pre-commit hook (requires `git config core.hooksPath .githooks`)

## Archive
- Removed content (k8s, AD lab, OpenPLC, journals, notes) lives at the `v1-archive` tag
- Restore with: `git checkout v1-archive -- path/to/file`
- `scripts/migrate-content.sh` extracts journal/notes from the tag into Hugo drafts

## Blog Publishing Workflow
- Journal entries from v1-archive → migrate script → drafts in site/content/posts/
- Run `scripts/audit-content.sh` to check for PII before publishing
- Set `draft: false` and rewrite in first person before publishing
- Internal IPs used as examples in blog posts are fine (illustrate the problem)
- deploy-blog workflow auto-publishes on push to main

## Gitleaks
- CI workflow scans full history on push/PR
- `.gitleaksbaseline` is empty — history was rewritten clean with git-filter-repo
- `.gitleaks.toml` has custom rules for email header PII patterns
- Pre-commit hook in `.githooks/` — runs `gitleaks protect --staged`

## Git History
- History was rewritten with git-filter-repo to remove secrets/PII
- `main` tracking may drop after filter-repo — fix with `git branch --set-upstream-to=origin/main main`
- filter-repo removes the `origin` remote — re-add with `git remote add origin git@github.com:8do-abehn/lab.git`
- filter-repo leaves `.git/filter-repo/already_ran` — delete it before re-running

## Issue Priority Labels
- `priority:critical` — broken in prod, fix now
- `priority:high` — blocks other work, fix this sprint
- `priority:medium` — fix soon, not blocking
- `priority:low` — nice to have, backlog

## Hugo
- Build: `cd site && hugo --minify`
- Hugo is installed via Homebrew
- Theme is a git submodule at site/themes/PaperMod
