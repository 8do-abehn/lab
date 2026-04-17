# rockbox-nano

Replaces Apple Music + Finder sync for an **iPod nano 2nd gen** (model A1199) by:

1. Installing **Rockbox 4.0** as the iPod's firmware (one-time, dual-boots with Apple OS)
2. Pulling music from the Jellyfin server (`jellyfin01:/mnt/library/music/`) over the tailnet
3. Transcoding any FLAC tracks to 192k MP3 on the way to the device
4. Treating the iPod as a plain USB mass-storage device — no iTunes database, no Apple Music

## Files

| File | Purpose |
|---|---|
| `setup.sh` | Builds `ipodpatcher` from source and downloads the bootloader + firmware zip. Idempotent. |
| `sync-to-ipod.sh` | Pulls selected artists, transcodes FLAC, copies to `/Volumes/BEHN IPOD/Music/`. Dry-run by default. |
| `.gitignore` | Excludes the compiled binary, downloaded blobs, and the staging dir. |

## One-time setup

```sh
./setup.sh                       # builds ipodpatcher + downloads bootloader + firmware zip
```

This populates `~/8do/rockbox-nano/` with the binaries and blobs. Override with `ROCKBOX_NANO_WORKDIR=...`.

## One-time Rockbox install (per iPod)

> Pre-requisite: confirm the iPod is `winpod` (FAT32). On macOS, Apple Music typically formats as HFS+ (`macpod`) which Rockbox cannot use. The nano needs to be in FAT32 — either it already is (pre-existing Windows-formatted iPod) or it can be converted on macOS using `mbr-nano2g.bin` + `ipodpatcher -f`.

```sh
cd ~/8do/rockbox-nano

# Backup the original Apple firmware (insurance — keep the .ipodx file safe)
sudo ./ipodpatcher -rf apple-original-firmware.ipodx

# Install the Rockbox bootloader (writes to firmware partition only)
sudo ./ipodpatcher -a bootloader-ipodnano2g.ipodx

# Extract the Rockbox firmware files to the iPod's data partition
unzip -o rockbox-ipodnano2g-4.0.zip -d "/Volumes/BEHN IPOD/"

diskutil eject "/Volumes/BEHN IPOD"
```

On reboot the iPod loads the Rockbox bootloader, which then loads `.rockbox/rockbox.ipod` from the data partition.

**Dual-boot keys (during boot):**

- *No key* → Rockbox
- *Hold `Menu`* → Apple firmware (chained from `OSBK` slot in firmware partition)
- *Hold `Select`* (center) → Apple disk mode (USB mass storage recovery)

## Verifying the bootloader is installed

```sh
sudo ./ipodpatcher --list
```

The "Main firmware" image should be ~52 KB (Rockbox bootloader). If it's several MB, that's Apple firmware and the bootloader install hasn't happened.

## Music sync

Edit the `ARTISTS` array in `sync-to-ipod.sh`. Entries are `<subdir>/<Artist Name>` relative to `/mnt/library/music/` on jellyfin (e.g. `library/Sturgill Simpson`, `krista/Nine Inch Nails`).

```sh
./sync-to-ipod.sh           # dry-run
./sync-to-ipod.sh --go      # actually copy to iPod
```

Re-runnable; `rsync --size-only` skips files already on the iPod, and the FLAC transcode loop only acts on remaining `.flac` files.

## Playlists

Rockbox auto-discovers `.m3u`/`.m3u8` files in `/Playlists/` on the iPod. Generate one with absolute paths from the iPod root:

```sh
mkdir -p "/Volumes/BEHN IPOD/Playlists"
find "/Volumes/BEHN IPOD/Music/Radiohead" -type f \
    \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.flac" \) ! -name "._*" \
    | sort | sed "s|/Volumes/BEHN IPOD||" \
    > "/Volumes/BEHN IPOD/Playlists/Radiohead.m3u8"
```

Use `.m3u8` (UTF-8) when track names contain unicode characters.

## Battery health

Check live battery voltage on-device: **System → Debug → View Battery** in Rockbox.

For nano 2g specifically, the original Apple recall (overheating) only applied to the 1st generation. The 2nd gen is safe but a 20-year-old cell will be capacity-degraded — see [lab issue #365](../../../../issues/365) for replacement notes (requires soldering, see [iFixit Guide #422](https://www.ifixit.com/Guide/iPod+Nano+2nd+Generation+Battery+Replacement/422)).

## Design notes

A few things that took debugging the first time around — preserved here so the next person (probably future-me) doesn't repeat them:

### Use GNU rsync, not Apple's openrsync

macOS ships `openrsync` which lacks `--protect-args` (`-s`). That flag is mandatory when remote paths contain spaces (and they will — "Sturgill Simpson", "A Moon Shaped Pool", etc.) because the remote shell otherwise re-interprets the filenames.

```sh
brew install rsync   # puts GNU rsync 3.x first in PATH
```

### `ffmpeg -nostdin` is mandatory inside `while read` loops

Without it, ffmpeg reads from the loop's stdin (which is the `find -print0` pipe), consumes random bytes from upcoming filenames, and the loop iterates over corrupted paths. Symptom: only the first FLAC transcodes, then the script either dies on a mangled path or silently exits with no warning. Took an hour to figure out.

### `-vn` drops embedded album art

The nano's screen is too small for embedded cover art and Rockbox reads art from a separate `cover.jpg` per album folder anyway. Stripping it speeds the encode ~5x and avoids ffmpeg's bizarre still-image-as-video warnings.

### macOS resource forks pollute the source

The cephfs library has `._<filename>` AppleDouble files everywhere from past Mac copies. Excluded via `--exclude='._*'` in rsync — Rockbox will try to parse them as audio files and choke otherwise.

### iPod must be `winpod` (FAT32), not `macpod` (HFS+)

If `ipodpatcher --scan` reports "macpod", you need the conversion path:

```sh
curl -fLO https://download.rockbox.org/bootloader/ipod/mbr-nano2g-2GB.bin   # or 4GB variant
diskutil unmountDisk /dev/diskN          # double-check N from `diskutil list`!
sudo dd if=mbr-nano2g-2GB.bin of=/dev/diskN bs=512 count=1
sudo ./ipodpatcher -f                    # format data partition as FAT32
# then proceed with bootloader install
```

The `dd` step is the high-stakes part; verify `diskN` matches the iPod size (2GB or 4GB) before running.

### Reclaiming legacy iTunes space

Once Rockbox is confirmed working, the old `iPod_Control/` directory from Apple's sync era is wasted space (Rockbox doesn't read iTunesDB). Free it:

```sh
rm -rf "/Volumes/BEHN IPOD/iPod_Control"
```

This recovered ~1.6 GB on a 4 GB nano. Calendars/Contacts/Notes are separate top-level folders and unaffected.

## References

- [Rockbox iPod Nano 2nd Gen port](https://www.rockbox.org/wiki/IPodNano2GPort)
- [Rockbox 4.0 manual for ipodnano2g](https://download.rockbox.org/manual/rockbox-ipodnano2g/)
- [iFixit nano 2g battery replacement guide #422](https://www.ifixit.com/Guide/iPod+Nano+2nd+Generation+Battery+Replacement/422)
