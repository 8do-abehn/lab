#!/usr/bin/env bash
# Bootstrap the rockbox-nano workspace.
# Idempotent: re-running just verifies/refreshes anything missing.
#
# Builds ipodpatcher from source and downloads the firmware bits needed
# to install Rockbox 4.0 on an iPod nano 2nd generation (model A1199).
#
# After running this, see README.md for the install procedure.
set -euo pipefail

WORKDIR="${ROCKBOX_NANO_WORKDIR:-$HOME/8do/rockbox-nano}"
ROCKBOX_VERSION="4.0"
ROCKBOX_SRC_REPO="https://github.com/Rockbox/rockbox.git"
DL_BASE="https://download.rockbox.org"

log() { printf '[setup] %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v git  >/dev/null || die "git required"
command -v make >/dev/null || die "make required (xcode-select --install)"
command -v cc   >/dev/null || die "cc required (xcode-select --install)"
command -v curl >/dev/null || die "curl required"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# --- ipodpatcher (built from source; no working macOS binary upstream) ----
# Rockbox only ships a 2010 Intel macOS dmg of ipodpatcher which doesn't run
# on modern macOS. The C source builds cleanly with the system toolchain.
if [[ ! -x ./ipodpatcher ]]; then
    log "compiling ipodpatcher from source"
    if [[ ! -d /tmp/rockbox-src ]]; then
        git clone --depth 1 "$ROCKBOX_SRC_REPO" /tmp/rockbox-src
    fi
    make -C /tmp/rockbox-src/utils/ipodpatcher >/dev/null
    cp /tmp/rockbox-src/utils/ipodpatcher/ipodpatcher ./ipodpatcher
    chmod +x ./ipodpatcher
else
    log "ipodpatcher already built"
fi

# --- bootloader (encrypted .ipodx for nano2g) -----------------------------
if [[ ! -f bootloader-ipodnano2g.ipodx ]]; then
    log "downloading nano2g bootloader"
    curl -fLO "$DL_BASE/bootloader/ipod/bootloader-ipodnano2g.ipodx"
else
    log "bootloader already present"
fi

# --- Rockbox firmware zip (extracted to iPod's data partition) ------------
ROCKBOX_ZIP="rockbox-ipodnano2g-${ROCKBOX_VERSION}.zip"
if [[ ! -f "$ROCKBOX_ZIP" ]]; then
    log "downloading Rockbox $ROCKBOX_VERSION for ipodnano2g"
    curl -fLO "$DL_BASE/release/${ROCKBOX_VERSION}/${ROCKBOX_ZIP}"
else
    log "$ROCKBOX_ZIP already present"
fi

log "done. workspace: $WORKDIR"
log "run sync-to-ipod.sh (dry-run by default; --go to write to iPod)"
