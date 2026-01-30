#!/bin/bash
set -euo pipefail

# AD Lab VM Creation Script for Proxmox (pve008)
# Storage: sda4tb
# Network: vmbr1 (VLAN 50 - 10.150.50.0/24)

ISO_SERVER="local:iso/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
ISO_WIN11="local:iso/26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_LTSC_EVAL_x64FRE_en-us.iso"
ISO_UBUNTU="local:iso/ubuntu-24.04.3-live-server-amd64.iso"
ISO_VIRTIO="local:iso/virtio-win.iso"

# DC01 - Primary Domain Controller (1001)
echo "Creating DC01..."
qm create 1001 --name DC01 --memory 4096 --cores 2 --cpu host
qm set 1001 --bios ovmf --machine q35 --ostype win11
qm set 1001 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1001 --tpmstate0 sda4tb:1,version=v2.0
qm set 1001 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1001 --net0 virtio,bridge=vmbr1
qm set 1001 --ide2 ${ISO_SERVER},media=cdrom
qm set 1001 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1001 --boot order=ide2

# DC02 - Secondary Domain Controller (1002)
echo "Creating DC02..."
qm create 1002 --name DC02 --memory 4096 --cores 2 --cpu host
qm set 1002 --bios ovmf --machine q35 --ostype win11
qm set 1002 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1002 --tpmstate0 sda4tb:1,version=v2.0
qm set 1002 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1002 --net0 virtio,bridge=vmbr1
qm set 1002 --ide2 ${ISO_SERVER},media=cdrom
qm set 1002 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1002 --boot order=ide2

# FS01 - File Server (1003)
echo "Creating FS01..."
qm create 1003 --name FS01 --memory 4096 --cores 2 --cpu host
qm set 1003 --bios ovmf --machine q35 --ostype win11
qm set 1003 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1003 --tpmstate0 sda4tb:1,version=v2.0
qm set 1003 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1003 --scsi1 sda4tb:100,discard=on,ssd=1
qm set 1003 --net0 virtio,bridge=vmbr1
qm set 1003 --ide2 ${ISO_SERVER},media=cdrom
qm set 1003 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1003 --boot order=ide2

# WS01 - Tier 0 PAW (1004)
echo "Creating WS01..."
qm create 1004 --name WS01 --memory 4096 --cores 2 --cpu host
qm set 1004 --bios ovmf --machine q35 --ostype win11
qm set 1004 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1004 --tpmstate0 sda4tb:1,version=v2.0
qm set 1004 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1004 --net0 virtio,bridge=vmbr1
qm set 1004 --ide2 ${ISO_WIN11},media=cdrom
qm set 1004 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1004 --boot order=ide2

# WS02 - Helpdesk (1005)
echo "Creating WS02..."
qm create 1005 --name WS02 --memory 4096 --cores 2 --cpu host
qm set 1005 --bios ovmf --machine q35 --ostype win11
qm set 1005 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1005 --tpmstate0 sda4tb:1,version=v2.0
qm set 1005 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1005 --net0 virtio,bridge=vmbr1
qm set 1005 --ide2 ${ISO_WIN11},media=cdrom
qm set 1005 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1005 --boot order=ide2

# WS03 - End User (1006)
echo "Creating WS03..."
qm create 1006 --name WS03 --memory 4096 --cores 2 --cpu host
qm set 1006 --bios ovmf --machine q35 --ostype win11
qm set 1006 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=1
qm set 1006 --tpmstate0 sda4tb:1,version=v2.0
qm set 1006 --scsi0 sda4tb:60,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1006 --net0 virtio,bridge=vmbr1
qm set 1006 --ide2 ${ISO_WIN11},media=cdrom
qm set 1006 --ide0 ${ISO_VIRTIO},media=cdrom
qm set 1006 --boot order=ide2

# LINUX01 - Ubuntu AD Client (1007)
echo "Creating LINUX01..."
qm create 1007 --name LINUX01 --memory 2048 --cores 2 --cpu host
qm set 1007 --bios ovmf --machine q35 --ostype l26
qm set 1007 --efidisk0 sda4tb:1,efitype=4m,pre-enrolled-keys=0
qm set 1007 --scsi0 sda4tb:40,discard=on,ssd=1 --scsihw virtio-scsi-single
qm set 1007 --net0 virtio,bridge=vmbr1
qm set 1007 --ide2 ${ISO_UBUNTU},media=cdrom
qm set 1007 --boot order=ide2

echo "Done. VMs 1002-1007 created."
echo ""
echo "VM Summary:"
echo "  1001 - DC01 (already exists)"
echo "  1002 - DC02"
echo "  1003 - FS01 (60GB + 100GB data)"
echo "  1004 - WS01 (Tier 0 PAW)"
echo "  1005 - WS02 (Helpdesk)"
echo "  1006 - WS03 (End User)"
echo "  1007 - LINUX01"
