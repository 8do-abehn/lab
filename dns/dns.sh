#!/usr/bin/env bash
#
# octoDNS wrapper for the personal email domains.
#
# Loads the Cloudflare API token from a file outside the repo so the token
# never lands in shell history, process listings, or a committed file.
#
# Usage:
#   ./dns.sh dump    Pull live zones from Cloudflare into ./zones (first run)
#   ./dns.sh plan    Show what would change. Read only, safe to run anytime.
#   ./dns.sh apply   Actually push changes to Cloudflare.

set -euo pipefail

TOKEN_FILE="${CLOUDFLARE_TOKEN_FILE:-$HOME/.config/octodns/cloudflare-token}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: token file not found at $TOKEN_FILE" >&2
  echo "See dns/README.md for how to create it." >&2
  exit 1
fi

# Refuse to run if the token file is readable by anyone else
perms="$(stat -f '%A' "$TOKEN_FILE")"
if [[ "$perms" != "600" ]]; then
  echo "ERROR: $TOKEN_FILE has permissions $perms, expected 600." >&2
  echo "Fix with: chmod 600 $TOKEN_FILE" >&2
  exit 1
fi

# Exported rather than passed on the command line so it stays out of ps output
CLOUDFLARE_API_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
export CLOUDFLARE_API_TOKEN

case "${1:-}" in
  dump)
    # Writes live state into ./zones. Overwrites local files, so only for
    # the initial import or a deliberate re-sync from Cloudflare.
    for zone in abehn.com. b3hn.com. behn.email.; do
      echo "==> dumping $zone"
      octodns-dump --config-file=config.yaml --output-dir=zones "$zone" cloudflare
    done
    ;;
  plan)
    # octodns-sync is dry run unless --doit is passed
    octodns-sync --config-file=config.yaml
    ;;
  apply)
    octodns-sync --config-file=config.yaml --doit
    ;;
  *)
    echo "Usage: $0 {dump|plan|apply}" >&2
    exit 1
    ;;
esac
