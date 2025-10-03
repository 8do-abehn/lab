#!/bin/bash
#
# Load Proxmox credentials and SSH keys from Bitwarden
#
# This script retrieves credentials from Bitwarden and:
# - Exports Proxmox API token as PKR_VAR and TF_VAR environment variables
# - Exports SSH keys to ~/.ssh/ directory
# - Sets PKR_VAR_ssh_public_key for Packer builds
#
# Customize the following variables for your environment:
# - ITEM_NAME: Your Bitwarden login item name for Proxmox API token
# - SSH_ITEM_NAME: Your Bitwarden SSH key item name
# - SSH key file paths in the "Write SSH keys to files" section
#
# Usage:
#   export BW_SESSION=$(bw unlock --raw)
#   source set-proxmox-creds.sh
#

# Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI (bw) is not installed"
    exit 1
fi

# Check if vault is unlocked
if [ "$(bw status | jq -r '.status')" != "unlocked" ]; then
    echo "Error: Bitwarden vault is locked. Please unlock it first:"
    echo "  export BW_SESSION=\$(bw unlock --raw)"
    exit 1
fi

# Retrieve Proxmox API token from Bitwarden
# CUSTOMIZE: Replace with your Bitwarden login item name
ITEM_NAME="token - terraform-k8s"
ITEM=$(bw get item "$ITEM_NAME" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Could not retrieve item '$ITEM_NAME' from Bitwarden"
    exit 1
fi

# Extract username and password
USERNAME=$(echo "$ITEM" | jq -r '.login.username')
PASSWORD=$(echo "$ITEM" | jq -r '.login.password')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Could not extract credentials from Bitwarden item"
    exit 1
fi

# Retrieve and extract SSH keys from Bitwarden
# CUSTOMIZE: Replace with your Bitwarden SSH key item name
SSH_ITEM_NAME="ssh key"
PRIVATE_KEY=$(bw get item "$SSH_ITEM_NAME" 2>/dev/null | jq -r '.sshKey.privateKey // empty')
PUBLIC_KEY=$(bw get item "$SSH_ITEM_NAME" 2>/dev/null | jq -r '.sshKey.publicKey // empty')

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    echo "Error: Could not extract SSH keys from Bitwarden item"
    exit 1
fi

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# CUSTOMIZE: Replace key filenames with your preferred names
# Remove existing keys if they exist (to avoid permission issues)
rm -f ~/.ssh/id_ed25519_8do ~/.ssh/id_ed25519_8do.pub

# Write SSH keys to files
echo "$PRIVATE_KEY" > ~/.ssh/id_ed25519_8do
echo "$PUBLIC_KEY" > ~/.ssh/id_ed25519_8do.pub

# Set correct permissions
chmod 600 ~/.ssh/id_ed25519_8do
chmod 644 ~/.ssh/id_ed25519_8do.pub

# Export Packer variables
export PKR_VAR_proxmox_api_token_id="$USERNAME"
export PKR_VAR_proxmox_api_token_secret="$PASSWORD"
# CUSTOMIZE: Update if you changed the SSH key filename above
export PKR_VAR_ssh_public_key="~/.ssh/id_ed25519_8do.pub"

# Export Terraform variables
export TF_VAR_proxmox_api_token_id="$USERNAME"
export TF_VAR_proxmox_api_token_secret="$PASSWORD"

echo "✓ Proxmox credentials loaded from Bitwarden"
echo "  PKR_VAR_proxmox_api_token_id set"
echo "  PKR_VAR_proxmox_api_token_secret set"
echo "  PKR_VAR_ssh_public_key set"
echo "  TF_VAR_proxmox_api_token_id set"
echo "  TF_VAR_proxmox_api_token_secret set"
echo ""
echo "✓ SSH keys exported from Bitwarden"
echo "  Private key: ~/.ssh/id_ed25519_8do"
echo "  Public key: ~/.ssh/id_ed25519_8do.pub"
echo ""
echo "Run this command to use in your current shell:"
echo "  source k8s/set-proxmox-creds.sh"
