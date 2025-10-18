# GitHub Actions Workflows

This directory contains CI/CD workflows for managing the infrastructure with Ansible.

## Workflows

### [`ansible-ci.yml`](workflows/ansible-ci.yml)
**Automatic CI on Pull Requests**

Runs automatically when you create a PR that modifies Ansible files. Provides safety validation before merging changes.

**Jobs:**
1. **Lint** - Validates Ansible code quality with `ansible-lint`
2. **Test Infrastructure** - Connects via Tailscale and runs playbook in `--check` mode

**Safe:** Only performs dry-run validation, no actual changes made.

### [`ansible-deploy.yml`](workflows/ansible-deploy.yml)
**Manual Deployment Workflow**

Manually triggered workflow for deploying changes to infrastructure.

**Usage:**
1. Go to **Actions** tab in GitHub
2. Select **Ansible Deploy (Manual)** workflow
3. Click **Run workflow**
4. Choose:
   - Which playbook to run
   - Optionally limit to specific hosts
5. Confirm and run

**Warning:** Makes real changes to infrastructure. Use carefully.

## Setup Required

Before using these workflows, you must configure GitHub Secrets and Tailscale ACLs.

**See:** [`SECRETS.md`](SECRETS.md) for detailed setup instructions.

### Quick Setup Checklist

- [ ] Create Tailscale OAuth client with `auth_keys` scope and `tag:ci`
- [ ] Add `TS_OAUTH_CLIENT_ID` secret to GitHub
- [ ] Add `TS_OAUTH_SECRET` secret to GitHub
- [ ] Add `SSH_PRIVATE_KEY` secret to GitHub
- [ ] Add `ANSIBLE_VAULT_PASSWORD` secret to GitHub
- [ ] Configure Tailscale ACLs to allow `tag:ci` access to infrastructure

## Workflow Behavior

### On Pull Requests
```
PR created/updated
  ↓
Lint ansible files
  ↓ (if pass)
Connect to infrastructure via Tailscale
  ↓
Run playbook in --check mode
  ↓
Report results in PR
```

### Manual Deployment
```
Manually trigger from Actions tab
  ↓
Connect to infrastructure via Tailscale
  ↓
Run selected playbook (for real)
  ↓
Report results
```

## Security

- **Ephemeral Nodes:** GitHub runners connect temporarily and are auto-removed
- **No Persistence:** Runners don't stay on your network after workflow completes
- **Scoped Access:** `tag:ci` nodes only get access you explicitly grant in ACLs
- **Encrypted Secrets:** All credentials stored in GitHub's encrypted secret storage
- **Audit Trail:** All workflow runs are logged and reviewable

## Example: Creating a Safe Change

1. Create a feature branch:
   ```bash
   git checkout -b feat/update-netdata
   ```

2. Make your Ansible changes:
   ```bash
   vim ansible/roles/netdata/tasks/main.yml
   ```

3. Commit and push:
   ```bash
   git add ansible/
   git commit -m "netdata: update to version X"
   git push origin feat/update-netdata
   ```

4. Create PR on GitHub
   - CI automatically runs lint + check mode
   - Review the diff output in the Actions log
   - If everything looks good, merge the PR

5. After merge, manually trigger deployment:
   - Go to Actions → Ansible Deploy (Manual)
   - Select playbook and run
   - Monitor deployment

## Troubleshooting

### Tailscale Connection Issues
- Verify OAuth client has `auth_keys` scope
- Check that `tag:ci` exists in your Tailscale ACLs
- Ensure ACLs grant `tag:ci` access to your hosts

### SSH Authentication Failures
- Verify `SSH_PRIVATE_KEY` secret is correct
- Check that the key has access to your infrastructure hosts
- Ensure SSH key is in the correct format (PEM)

### Vault Decryption Errors
- Verify `ANSIBLE_VAULT_PASSWORD` secret is correct
- Ensure vault.yml is properly encrypted with the same password

### Linting Failures
- Run `ansible-lint` locally to see specific issues
- Fix issues and commit
- CI will re-run on new commit
