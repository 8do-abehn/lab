# PGP/GPG Key Setup for Git Signing

Guide for setting up PGP/GPG keys for git commit signing on a new machine.

## Prerequisites

- Access to 8do Bitwarden account (contains PGP keys and passphrase)
- GPG installed on the system
- Git installed
- (Optional) Bitwarden CLI for automated key retrieval

## Key Information

- **Key ID**: `406A763538074289`
- **Email**: `adam.behn@8devops.com`
- **Key Type**: RSA 4096-bit
- **Created**: 2025-10-02
- **Expires**: Subkeys expire 2033-09-30
- **Storage**: Keys stored in 8do Bitwarden
- **Passphrase**: Uses the keybase password

## Setup Steps

### 1. Retrieve Keys from Bitwarden

The GPG keys are stored in the **8do Bitwarden** account. Download them from Bitwarden and save to your home directory:
- `~/pgp_private` - Private key file
- `~/pgp_public` - Public key file

Alternatively, use Bitwarden CLI to retrieve them:

```bash
# Login to Bitwarden (if not already)
bw login

# Unlock vault and get session key
export BW_SESSION=$(bw unlock --raw)

# Retrieve and save keys (adjust item name/ID as needed)
# bw get attachment pgp_private <item-id> --output ~/pgp_private
# bw get attachment pgp_public <item-id> --output ~/pgp_public
```

### 2. Import Keys into GPG

```bash
# Import public key
gpg --import ~/pgp_public

# Import private key (will prompt for passphrase - use keybase password)
gpg --import ~/pgp_private
```

**Note**: When prompted for the passphrase during import, use the **keybase password** (also stored in 8do Bitwarden).

### 3. Verify Import

```bash
# List all secret keys
gpg --list-secret-keys --keyid-format=long

# Should show:
# sec   rsa4096/406A763538074289 2025-10-02 [SC]
#       41D280764C02421C70E26395406A763538074289
# uid                 [unknown] Adam Behn <adam.behn@8devops.com>
# ssb   rsa2048/BB52AF7C289B25A5 2025-10-02 [E]
# ssb   rsa2048/60ACC079EEC1DD45 2025-10-02 [SA]
```

### 4. Configure Git

```bash
# Set signing key
git config --global user.signingkey 406A763538074289

# Set user info (use GitHub noreply email for privacy)
git config --global user.email 8do-abehn@users.noreply.github.com
git config --global user.name "Adam Behn"

# Enable automatic commit signing
git config --global commit.gpgsign true

# Specify GPG program
git config --global gpg.program gpg
```

**Note**: We use GitHub's noreply email (`8do-abehn@users.noreply.github.com`) for the git author to protect email privacy, even though the GPG key itself contains `adam.behn@8devops.com`. The commit author email is what GitHub displays publicly.

### 5. Set Ultimate Trust on Your Key

To avoid "WARNING: This key is not certified" messages:

```bash
# Import ownertrust (6 = ultimate trust)
echo "41D280764C02421C70E26395406A763538074289:6:" | gpg --import-ownertrust
```

### 6. Verify Configuration

```bash
# Check git config
git config --global --list | grep -E "(user\.|gpg|sign)"

# Should show:
# user.email=8do-abehn@users.noreply.github.com
# user.name=Adam Behn
# user.signingkey=406A763538074289
# commit.gpgsign=true
# gpg.program=gpg
```

### 7. Test Signing

```bash
# Create a test commit
mkdir /tmp/test_gpg && cd /tmp/test_gpg
git init
echo "test" > test.txt
git add test.txt
git commit -m "Test GPG signing"

# Verify signature
git log --show-signature -1

# Should show:
# gpg: Good signature from "Adam Behn <adam.behn@8devops.com>" [ultimate]
```

## Verification

After setup, every commit will be automatically signed. You can verify signatures with:

```bash
# View signature for last commit
git log --show-signature -1

# View all commits with signature status
git log --pretty="format:%h %G? %aN  %s"
```

Signature status codes:
- `G` = Good signature
- `B` = Bad signature
- `U` = Good signature, unknown validity
- `X` = Good signature, expired
- `Y` = Good signature, expired key
- `R` = Good signature, revoked key
- `E` = Cannot check signature
- `N` = No signature

## Export Public Key for GitHub/GitLab

To add your public key to GitHub/GitLab for verified commits:

```bash
# Export public key in ASCII format
gpg --armor --export 406A763538074289

# Copy the output and add to:
# GitHub: Settings → SSH and GPG keys → New GPG key
# GitLab: Settings → GPG Keys → Add new key
```

## Troubleshooting

### "gpg: signing failed: Inappropriate ioctl for device"

```bash
export GPG_TTY=$(tty)
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

### "gpg: signing failed: No secret key"

Verify the key is imported:
```bash
gpg --list-secret-keys
```

### Commits not being signed

Check git config:
```bash
git config --get commit.gpgsign  # should return: true
git config --get user.signingkey  # should return: 406A763538074289
```

### "GH007: Your push would publish a private email address"

GitHub's email privacy protection is enabled. Update your git email to use GitHub's noreply address:

```bash
# Update to GitHub noreply email
git config --global user.email 8do-abehn@users.noreply.github.com

# If you already have commits with the wrong email, amend them:
git rebase -i HEAD~N --exec 'git commit --amend --no-edit --reset-author'
# (replace N with the number of commits to fix)
```

## Key Management

### Backup Keys

```bash
# Export private key (keep secure!)
gpg --export-secret-keys --armor 406A763538074289 > pgp_private_backup.asc

# Export public key
gpg --export --armor 406A763538074289 > pgp_public_backup.asc
```

### Renew Expiring Subkeys

```bash
# Edit key
gpg --edit-key 406A763538074289

# Select subkey and extend expiration
# gpg> key 1
# gpg> expire
# gpg> save
```

## References

- [Git Commit Signing Documentation](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)
- [GitHub GPG Signature Verification](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [GPG Documentation](https://gnupg.org/documentation/)
