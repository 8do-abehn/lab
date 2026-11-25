#!/bin/bash
# Proxmox hookscript for VMs with a passed-through PCI device (tasks/vfio-hookscript.yml).
#
# VFIO pins every page of guest RAM before the guest runs. When the node's memory is
# mostly page cache, the kernel has to reclaim it (and swap) page by page while pinning,
# which on 2026-11-24 took vm-seb (701) past qm start's timeout: QEMU hung in D state,
# the GPU never got an image and the guest agent never came up. Dropping the clean page
# cache first leaves the pin with free pages to take, and the start finished in ~6s.
#
# Called by Proxmox as: <script> <vmid> <phase>
set -euo pipefail

vmid="$1"
phase="$2"

if [ "$phase" = "pre-start" ]; then
    # sync first so dirty pages become clean and droppable; 1 = page cache only,
    # dentries and inodes are cheap to keep and not what blocks the pin
    sync
    echo 1 > /proc/sys/vm/drop_caches
    logger -t vfio-drop-caches "VM ${vmid}: dropped page cache before start"
fi

exit 0
