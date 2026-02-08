#!/usr/bin/env bash
set -euo pipefail

# Migrate markdown content to Hugo site with frontmatter
# All content starts as draft: true for privacy review

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"
SITE_DIR="$LAB_ROOT/site"
CONTENT_DIR="$SITE_DIR/content"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[migrate]${NC} $1"; }
warn() { echo -e "${YELLOW}[migrate]${NC} $1"; }

# Extract title from first H1 or filename
extract_title() {
    local file="$1"
    local title

    # Try to find first H1 heading
    title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' | sed 's/ 🚀$//' | sed 's/ 🎮$//' || true)

    if [[ -z "$title" ]]; then
        # Fall back to filename
        title=$(basename "$file" .md | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    fi

    echo "$title"
}

# Extract date from filename (YYYY-MM-DD format)
extract_date() {
    local file="$1"
    local basename
    basename=$(basename "$file")

    if [[ "$basename" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Use file modification date as fallback
        stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || date +%Y-%m-%d
    fi
}

# Generate tags from content
generate_tags() {
    local file="$1"
    local tags=()

    # Check for common keywords
    if grep -qi 'proxmox\|pve' "$file"; then tags+=("proxmox"); fi
    if grep -qi 'ansible' "$file"; then tags+=("ansible"); fi
    if grep -qi 'tailscale' "$file"; then tags+=("tailscale"); fi
    if grep -qi 'gpu\|passthrough' "$file"; then tags+=("gpu-passthrough"); fi
    if grep -qi 'kubernetes\|k8s' "$file"; then tags+=("kubernetes"); fi
    if grep -qi 'docker\|container' "$file"; then tags+=("containers"); fi
    if grep -qi 'active.directory\|ad.lab\|windows.server' "$file"; then tags+=("active-directory"); fi
    if grep -qi 'jellyfin\|plex\|media' "$file"; then tags+=("media-server"); fi
    if grep -qi 'ci.cd\|github.actions\|pipeline' "$file"; then tags+=("ci-cd"); fi
    if grep -qi 'lxc' "$file"; then tags+=("lxc"); fi
    if grep -qi 'runbook' "$file"; then tags+=("runbook"); fi

    # Format as TOML array
    if [[ ${#tags[@]} -gt 0 ]]; then
        printf '['
        printf '"%s", ' "${tags[@]}" | sed 's/, $//'
        printf ']'
    else
        echo '[]'
    fi
}

# Add frontmatter to file
add_frontmatter() {
    local src="$1"
    local dest="$2"
    local section="$3"

    local title date tags
    title=$(extract_title "$src")
    date=$(extract_date "$src")
    tags=$(generate_tags "$src")

    # Create frontmatter
    cat > "$dest" << EOF
---
title: "$title"
date: $date
draft: true
tags: $tags
---

EOF

    # Append original content, skipping the first H1 if it matches title
    local first_line
    first_line=$(head -1 "$src")
    if [[ "$first_line" == "# "* ]]; then
        tail -n +2 "$src" >> "$dest"
    else
        cat "$src" >> "$dest"
    fi

    log "Migrated: $(basename "$src") -> $section/$(basename "$dest")"
}

# Migrate journal entries to posts/
migrate_journal() {
    log "Migrating journal entries..."
    for file in "$LAB_ROOT"/journal/*.md; do
        [[ -f "$file" ]] || continue
        local dest="$CONTENT_DIR/posts/$(basename "$file")"
        add_frontmatter "$file" "$dest" "posts"
    done
}

# Migrate AD Lab journal to projects/
migrate_ad_lab() {
    log "Migrating AD Lab entries..."
    for file in "$LAB_ROOT"/ad_lab/docs/journal/*.md; do
        [[ -f "$file" ]] || continue
        local dest="$CONTENT_DIR/projects/ad-lab-$(basename "$file")"
        add_frontmatter "$file" "$dest" "projects"
    done
}

# Migrate technical notes (curated selection)
migrate_notes() {
    log "Migrating technical notes..."

    # Technical/runbook files to include
    local include_files=(
        "proxmox-node-onboarding-runbook.md"
        "proxmox-node-decommission-runbook.md"
        "jellyfin-gpu-passthrough-lxc.md"
        "clonezilla-p2v-clone-instructions.md"
        "restore-disk2vhd-to-proxmox.md"
        "pgp-git-signing-setup.md"
        "netboot-xyz-pxe-server-setup.md"
        "pve007-amd-rx570-lxc-setup.md"
        "nvidia-3080-gpu-passthrough-planning.md"
        "dual-gpu-p2v-architecture.md"
        "proxmox-gpu-passthrough-gaming-setup.md"
        "favorite_commands.md"
        "ai-tool-integration-standards.md"
    )

    for filename in "${include_files[@]}"; do
        local file="$LAB_ROOT/notes/$filename"
        if [[ -f "$file" ]]; then
            local dest="$CONTENT_DIR/docs/$filename"
            add_frontmatter "$file" "$dest" "docs"
        else
            warn "Not found: $filename"
        fi
    done
}

# Main
main() {
    log "Starting content migration..."
    log "Source: $LAB_ROOT"
    log "Destination: $CONTENT_DIR"
    echo

    # Create section index files
    for section in posts projects docs reading; do
        if [[ ! -f "$CONTENT_DIR/$section/_index.md" ]]; then
            echo "---
title: \"$(echo "$section" | sed 's/\b\(.\)/\u\1/g')\"
---" > "$CONTENT_DIR/$section/_index.md"
        fi
    done

    migrate_journal
    echo
    migrate_ad_lab
    echo
    migrate_notes
    echo

    log "Migration complete!"
    log "All content is set to draft: true"
    log "Run scripts/audit-content.sh to check for sensitive data"
    log "Set draft: false on reviewed content to publish"
}

main "$@"
