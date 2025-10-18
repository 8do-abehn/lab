# GitHub Secrets Setup for Ansible CI/CD

This document describes the secrets required for the Ansible GitHub Actions workflows.

## Required Secrets

Go to your repository **Settings → Secrets and variables → Actions → New repository secret**

### 1. Tailscale OAuth Credentials

Create a Tailscale OAuth client for GitHub Actions:

1. Go to https://login.tailscale.com/admin/settings/oauth
2. Click **Generate OAuth client**
3. **Important OAuth Client Settings:**
   - **Scopes:** Select `auth_keys` (allows creating ephemeral nodes)
   - **Tags:** Select or create `tag:ci` (tags for CI/CD runners)
   - The OAuth client must have permission to grant the selected tags
4. Copy the **Client ID** and **Client secret**
5. **Important:** Store the client secret securely - it won't be shown again

Add these GitHub repository secrets:
- **`TS_OAUTH_CLIENT_ID`** - The OAuth client ID
- **`TS_OAUTH_SECRET`** - The OAuth client secret

**Note:** The GitHub Actions runner will register as an ephemeral node on your Tailscale network with the `tag:ci` tag. It will automatically be removed when the workflow completes.

### 2. SSH Private Key

Add your SSH private key that has access to your infrastructure:

- **`SSH_PRIVATE_KEY`** - Contents of `~/.ssh/id_ed25519_behner`

```bash
# Get the private key
cat ~/.ssh/id_ed25519_behner
```

**Security:** Ensure this key only has access to the hosts Ansible manages. Consider creating a dedicated CI/CD key pair.

### 3. Ansible Vault Password

Add your Ansible vault password:

- **`ANSIBLE_VAULT_PASSWORD`** - The password used to encrypt/decrypt your vault.yml

## Tailscale ACL Configuration

You'll need to add ACL rules for the `tag:ci` tag in your Tailscale admin console:

```json
{
  "tagOwners": {
    "tag:ci": ["your-email@example.com"],
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["proxmox:*", "k3s_cluster:*"],
    },
  ],
}
```

This allows CI runners to access your infrastructure hosts.

## Workflows

### `ansible-ci.yml` (Automatic on PR)
- **Trigger:** Pull requests that modify ansible files
- **Actions:**
  1. Runs `ansible-lint` for code quality
  2. Connects to your infrastructure via Tailscale
  3. Runs playbook in `--check --diff` mode (dry-run, shows what would change)
- **Safe:** No actual changes are made, just validation

### `ansible-deploy.yml` (Manual)
- **Trigger:** Manually triggered from GitHub Actions tab
- **Actions:**
  1. Connects to your infrastructure via Tailscale
  2. Actually applies changes by running the selected playbook
- **Options:**
  - Choose which playbook to run
  - Optionally limit to specific hosts
- **Use with caution:** Makes real changes to your infrastructure

## Security Notes

- CI runners connect as **ephemeral nodes** - automatically removed after workflow
- SSH keys and secrets are stored securely in GitHub encrypted secrets
- Vault password is never logged or exposed in workflow output
- Credentials are cleaned up at the end of each workflow run
- Use `--check` mode in CI for safety testing
- Manual deployment workflow requires explicit human approval
- OAuth tokens expire after 1 hour (handled automatically by the GitHub Action)

## Testing the Setup

1. Create a test branch with a small change to an Ansible file
2. Open a PR - the `ansible-ci.yml` workflow should trigger automatically
3. Check the Actions tab to see the workflow run
4. Review the `--check --diff` output to see what would be applied
