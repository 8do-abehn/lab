#!/usr/bin/env bash
set -euo pipefail

# Audit Hugo content for sensitive data before publishing
# Run this before setting draft: false on any content

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"
CONTENT_DIR="$LAB_ROOT/site/content"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ISSUES_FOUND=0

log() { echo -e "${GREEN}[audit]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[ISSUE]${NC} $1"; ISSUES_FOUND=$((ISSUES_FOUND + 1)); }

# Check for internal IP addresses
check_internal_ips() {
    log "Checking for internal IP addresses..."

    # Lab network patterns
    local patterns=(
        '10\.150\.[0-9]+\.[0-9]+'    # Lab network
        '192\.168\.[0-9]+\.[0-9]+'   # Common private
        '172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+'  # Private range
    )

    for pattern in "${patterns[@]}"; do
        while IFS= read -r match; do
            if [[ -n "$match" ]]; then
                error "$match"
            fi
        done < <(grep -rEn "$pattern" "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
    done
}

# Check for hostnames that reveal internal infrastructure
check_hostnames() {
    log "Checking for internal hostnames..."

    local patterns=(
        'pve[0-9]{3}'           # Proxmox hosts
        'dc[0-9]+'              # Domain controllers
        'fs[0-9]+'              # File servers
        '\.local\b'             # .local domains
        '\.home\b'              # Home domains
        '\.internal\b'          # Internal domains
        'behn\.ad'              # AD domain
    )

    for pattern in "${patterns[@]}"; do
        while IFS= read -r match; do
            if [[ -n "$match" ]]; then
                error "$match"
            fi
        done < <(grep -rEin "$pattern" "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
    done
}

# Check for email addresses
check_emails() {
    log "Checking for email addresses..."

    while IFS= read -r match; do
        if [[ -n "$match" ]]; then
            # Skip common placeholder/example emails
            if ! echo "$match" | grep -qE '(example\.com|test@|noreply@)'; then
                error "$match"
            fi
        fi
    done < <(grep -rEn '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
}

# Check for secrets/tokens
check_secrets() {
    log "Checking for potential secrets..."

    local patterns=(
        'password[[:space:]]*[:=]'
        'secret[[:space:]]*[:=]'
        'api[_-]?key[[:space:]]*[:=]'
        'token[[:space:]]*[:=]'
        'tskey-[a-zA-Z0-9]+'      # Tailscale keys
        'ghp_[a-zA-Z0-9]+'        # GitHub tokens
        'sk-[a-zA-Z0-9]+'         # OpenAI keys
        'AKIA[A-Z0-9]{16}'        # AWS keys
    )

    for pattern in "${patterns[@]}"; do
        while IFS= read -r match; do
            if [[ -n "$match" ]]; then
                error "$match"
            fi
        done < <(grep -rEin "$pattern" "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
    done
}

# Check for MAC addresses
check_mac_addresses() {
    log "Checking for MAC addresses..."

    while IFS= read -r match; do
        if [[ -n "$match" ]]; then
            error "$match"
        fi
    done < <(grep -rEn '([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}' "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
}

# Check for serial numbers and hardware IDs
check_hardware_ids() {
    log "Checking for hardware identifiers..."

    local patterns=(
        'serial[[:space:]]*[:=]'
        'uuid[[:space:]]*[:=]'
        'hwid[[:space:]]*[:=]'
    )

    for pattern in "${patterns[@]}"; do
        while IFS= read -r match; do
            if [[ -n "$match" ]]; then
                error "$match"
            fi
        done < <(grep -rEin "$pattern" "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
    done
}

# List files still in draft mode
list_drafts() {
    log "Files in draft mode:"
    grep -rl 'draft: true' "$CONTENT_DIR" --include="*.md" 2>/dev/null | while read -r file; do
        echo "  - $(basename "$file")"
    done
}

# List files ready to publish
list_ready() {
    log "Files ready to publish (draft: false):"
    grep -rl 'draft: false' "$CONTENT_DIR" --include="*.md" 2>/dev/null | while read -r file; do
        echo "  - $(basename "$file")"
    done || echo "  (none)"
}

# Main
main() {
    echo "========================================="
    echo "Content Privacy Audit"
    echo "========================================="
    echo

    if [[ ! -d "$CONTENT_DIR" ]]; then
        echo "Content directory not found: $CONTENT_DIR"
        echo "Run scripts/migrate-content.sh first"
        exit 1
    fi

    check_internal_ips
    echo
    check_hostnames
    echo
    check_emails
    echo
    check_secrets
    echo
    check_mac_addresses
    echo
    check_hardware_ids
    echo

    echo "========================================="
    if [[ $ISSUES_FOUND -gt 0 ]]; then
        echo -e "${RED}Found $ISSUES_FOUND potential issues${NC}"
        echo
        echo "Review each finding and either:"
        echo "  1. Redact/generalize the sensitive info"
        echo "  2. If it's a false positive, ignore it"
        echo
        echo "Only set draft: false after reviewing"
    else
        echo -e "${GREEN}No issues found!${NC}"
    fi

    echo
    list_drafts
    echo
    list_ready
}

main "$@"
