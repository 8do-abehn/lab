#!/usr/bin/env bash
set -euo pipefail

# Relay Google Takeout zips from this Mac to the Immich staging volume.
#
# Why this exists: the Takeout is ~606GB across 13 zips, this Mac has ~388GB
# free, and immich-go needs all 13 present at once because a photo's JSON
# sidecar can land in a different zip than the photo itself. So the Mac acts as
# a pass-through: download a few, relay them, delete locally, repeat. It never
# holds more than a couple at a time.
#
# Each file is verified on the far side BEFORE the local copy is deleted, since
# once it is gone the only remedy is re-downloading from Google, and that link
# expires.
#
# Usage:
#   scripts/takeout-relay.sh              # watch and relay until EXPECTED files are done
#   scripts/takeout-relay.sh --once       # single pass over whatever is ready now
#   SKIP_VERIFY=1 scripts/takeout-relay.sh    # size check only, no unzip -t
#
# Tunables:
#   SRC_DIR   where the browser downloads land  (default ~/Downloads)
#   DEST      rsync destination                 (default root@10.150.70.15:/staging)
#   PATTERN   glob for archives                 (default takeout-*.zip)
#   EXPECTED  how many files make a complete set (default 13)

SRC_DIR="${SRC_DIR:-$HOME/Downloads}"
DEST="${DEST:-root@10.150.70.15:/staging}"
PATTERN="${PATTERN:-takeout-*.zip}"
EXPECTED="${EXPECTED:-13}"
POLL_SECONDS="${POLL_SECONDS:-60}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"

DEST_HOST="${DEST%%:*}"
DEST_PATH="${DEST#*:}"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }

# Browsers rename partial downloads on completion (.crdownload, .part,
# .download), so a file appearing under its final name is usually finished.
# "Usually" is not good enough when the next step deletes the local copy, so
# also require the size to hold steady before touching it.
is_stable() {
    local f="$1" a b
    a=$(stat -f%z "$f" 2>/dev/null || echo 0)
    sleep 5
    b=$(stat -f%z "$f" 2>/dev/null || echo 0)
    [ "$a" = "$b" ] && [ "$a" != "0" ]
}

has_partial_sibling() {
    local f="$1"
    [ -e "${f}.crdownload" ] || [ -e "${f}.part" ] || [ -e "${f}.download" ]
}

# SC2029 is expected throughout: the paths are built from local config and are
# meant to expand here, not on the far side.
remote_size() {
    # shellcheck disable=SC2029
    ssh "$DEST_HOST" "stat -c%s '$DEST_PATH/$1' 2>/dev/null || echo 0"
}

relay() {
    local path="$1" name size rsize
    name=$(basename "$path")
    size=$(stat -f%z "$path")

    log "-> $name ($(numfmt --to=iec "$size" 2>/dev/null || echo "$size B")) transferring"
    # --partial keeps a resumable remainder if this is interrupted mid-file.
    # --no-o/--no-g so the far side does not inherit this Mac's uid, which does
    # not exist in the container and just looks like a bug later.
    rsync -a --no-o --no-g --partial --info=progress2 "$path" "$DEST/"

    rsize=$(remote_size "$name")
    if [ "$rsize" != "$size" ]; then
        log "!! $name size mismatch (local $size, remote $rsize) - keeping local copy"
        return 1
    fi

    if [ "$SKIP_VERIFY" != "1" ]; then
        log "   $name verifying archive integrity on the far side"
        # shellcheck disable=SC2029
        if ! ssh "$DEST_HOST" "unzip -t -qq '$DEST_PATH/$name'"; then
            log "!! $name failed integrity check - keeping local copy, re-download it"
            return 1
        fi
    fi

    rm -f "$path"
    log "<- $name verified and removed locally"
}

relayed_count() {
    # shellcheck disable=SC2029
    ssh "$DEST_HOST" "ls -1 '$DEST_PATH'/$PATTERN 2>/dev/null | wc -l" | tr -d ' '
}

main() {
    local once=0
    [ "${1:-}" = "--once" ] && once=1

    log "source      $SRC_DIR/$PATTERN"
    log "destination $DEST"
    log "expecting   $EXPECTED archives"

    while true; do
        shopt -s nullglob
        # Unquoted $PATTERN on purpose: this is the glob expansion.
        # shellcheck disable=SC2206
        local candidates=("$SRC_DIR"/$PATTERN)
        shopt -u nullglob

        for f in "${candidates[@]}"; do
            if has_partial_sibling "$f"; then
                log ".. $(basename "$f") still downloading, skipping"
                continue
            fi
            if ! is_stable "$f"; then
                log ".. $(basename "$f") size still changing, skipping"
                continue
            fi
            relay "$f" || true
        done

        local done_count
        done_count=$(relayed_count)
        log "== $done_count/$EXPECTED archives on $DEST_HOST"

        if [ "$done_count" -ge "$EXPECTED" ]; then
            log "all archives relayed; run immich-go on $DEST_HOST against $DEST_PATH/$PATTERN"
            break
        fi
        [ "$once" = "1" ] && break
        sleep "$POLL_SECONDS"
    done
}

main "$@"
