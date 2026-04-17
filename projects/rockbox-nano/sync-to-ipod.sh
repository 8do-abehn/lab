#!/usr/bin/env bash
# Sync selected artists from jellyfin01 cephfs to a Rockbox iPod.
# Transcodes FLAC to MP3 on the fly; leaves m4a/AAC as-is.
# Dry-run by default; pass --go to actually copy.
set -euo pipefail

JELLYFIN_HOST="jellyfin01"
MUSIC_ROOT="/mnt/library/music"
IPOD_MOUNT="/Volumes/BEHN IPOD"
STAGING="$HOME/8do/rockbox-nano/staging"
BITRATE="192k"
# Artists are stored as "<subdir>/<Artist Name>" relative to MUSIC_ROOT.
# Staging uses just the basename so the iPod ends up with /Music/<Artist>/...
ARTISTS=(
    "library/Sturgill Simpson"
    "library/Radiohead"
    "library/Chris Stapleton"
    "library/John Prine"
    "krista/Old Crow Medicine Show"
    "krista/My Morning Jacket"
    "krista/Kris Kristofferson"
    "krista/Nine Inch Nails"
    "krista/Sonic Youth"
    "krista/The Black Keys"
    "krista/Smashing Pumpkins"
    "adam/David Bowie"
)

DRY_RUN=1
[[ "${1:-}" == "--go" ]] && DRY_RUN=0

# rsync's handling of spaces in remote paths is fragile; -s (--protect-args)
# sends filenames to the remote without letting its shell re-interpret them.
RSYNC_OPTS=(
    -av
    -s
    --exclude='._*'
    --exclude='.DS_Store'
    --exclude='*.log'
    --exclude='*.cue'
    --exclude='*.m3u'
    --exclude='*.nfo'
    --exclude='*.jpg'
    --exclude='*.png'
)
(( DRY_RUN )) && RSYNC_OPTS+=(--dry-run)

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- pre-flight ----------------------------------------------------------
command -v ffmpeg >/dev/null || die "ffmpeg not found (brew install ffmpeg)"
command -v rsync  >/dev/null || die "rsync not found"
ssh -o ConnectTimeout=5 -o BatchMode=yes "$JELLYFIN_HOST" true 2>/dev/null \
    || die "cannot reach $JELLYFIN_HOST over ssh"

if (( ! DRY_RUN )); then
    [[ -d "$IPOD_MOUNT" ]] || die "iPod not mounted at $IPOD_MOUNT"
fi

mkdir -p "$STAGING"

# --- stage from jellyfin -------------------------------------------------
for entry in "${ARTISTS[@]}"; do
    artist="$(basename "$entry")"
    log "=== pulling: $artist ==="
    staging_artist="$STAGING/$artist"
    mkdir -p "$staging_artist"
    rsync "${RSYNC_OPTS[@]}" \
        "$JELLYFIN_HOST:$MUSIC_ROOT/$entry/" \
        "$staging_artist/"
done

# --- transcode FLAC -> MP3 in-place in staging --------------------------
log "=== transcoding FLAC -> MP3 @ $BITRATE ==="
flac_count=0
while IFS= read -r -d '' flac; do
    ((flac_count++)) || true
    mp3="${flac%.flac}.mp3"
    if (( DRY_RUN )); then
        log "  [dry-run] would transcode: ${flac#$STAGING/}"
        continue
    fi
    log "  $(basename "$flac")"
    # -nostdin: ffmpeg would otherwise read from the loop's stdin and consume
    # the rest of the find output, causing the loop to exit after one file.
    # -vn: drop embedded album art (the nano can't display it and it slows
    # encoding 5x). Rockbox reads cover art from a separate cover.jpg if present.
    ffmpeg -nostdin -hide_banner -loglevel error -y \
        -i "$flac" \
        -vn \
        -codec:a libmp3lame -b:a "$BITRATE" \
        -map_metadata 0 -id3v2_version 3 \
        "$mp3"
    rm -- "$flac"
done < <(find "$STAGING" -type f -iname '*.flac' -print0)
log "$flac_count FLAC files handled"

# --- copy staging to iPod ------------------------------------------------
if (( DRY_RUN )); then
    log "=== dry-run; staging size: $(du -sh "$STAGING" 2>/dev/null | awk '{print $1}') ==="
    log "run with --go to actually copy to iPod"
    exit 0
fi

log "=== copying to iPod ==="
mkdir -p "$IPOD_MOUNT/Music"
rsync -av --size-only \
    --exclude='._*' \
    --exclude='.DS_Store' \
    "$STAGING/" \
    "$IPOD_MOUNT/Music/"

log "=== done ==="
du -sh "$IPOD_MOUNT/Music"/* 2>/dev/null || true
df -h "$IPOD_MOUNT"
sync
log "run 'diskutil eject \"$IPOD_MOUNT\"' before unplugging"
