# Proxmox GPU Passthrough for Gaming - Technical Reference

**Last Updated**: 2025-10-24
**System**: Proxmox VE 8.x with NVIDIA RTX 3080 Ti
**Use Case**: Windows 11 gaming VM with GPU passthrough for Sunshine/Moonlight streaming

## Prerequisites

- NVIDIA GPU in dedicated PCIe slot
- IOMMU enabled in BIOS
- Proxmox VE 8.x installed
- GPU in clean IOMMU group (verify with `find /sys/kernel/iommu_groups/ -type l`)

## Part 1: Host Configuration

### 1.1 Verify IOMMU is Enabled

```bash
# Check GRUB configuration
cat /etc/default/grub | grep CMDLINE_LINUX_DEFAULT

# Should include (for AMD CPU):
# amd_iommu=on iommu=pt video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init

# For Intel CPU, use: intel_iommu=on
```

If missing, edit `/etc/default/grub`:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init"
```

Then update GRUB:
```bash
update-grub
```

### 1.2 Load VFIO Modules

Verify `/etc/modules` contains:
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Update initramfs:
```bash
update-initramfs -u -k all
```

### 1.3 Identify GPU PCI IDs

```bash
lspci -nn | grep -i nvidia
```

Example output:
```
3e:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080 Ti] [10de:2208]
3e:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef]
```

Note the vendor:device IDs: **10de:2208** and **10de:1aef**

### 1.4 Blacklist NVIDIA Drivers on Host

Create `/etc/modprobe.d/blacklist.conf`:
```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

### 1.5 Bind GPU to VFIO-PCI Driver

Create `/etc/modprobe.d/vfio.conf` (use your GPU's PCI IDs):
```
options vfio-pci ids=10de:2208,10de:1aef disable_vga=1
```

Update initramfs:
```bash
update-initramfs -u -k all
```

### 1.6 Reboot Host

```bash
reboot
```

### 1.7 Verify GPU is Bound to VFIO-PCI

After reboot:
```bash
lspci -nnk -d 10de:2208
```

Should show:
```
Kernel driver in use: vfio-pci
```

## Part 2: Download Required ISOs

### 2.1 Windows 11 ISO

Download from Microsoft and upload to Proxmox:
```bash
# On Proxmox host:
cd /var/lib/vz/template/iso/
wget https://path-to-windows-11.iso
```

Or use Proxmox GUI: Datacenter → Storage → local → ISO Images → Download from URL

### 2.2 VirtIO Drivers ISO

```bash
cd /var/lib/vz/template/iso/
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

## Part 3: Create Windows 11 VM via Proxmox GUI

### 3.1 General Tab
- **Node**: Your Proxmox node (e.g., pve007)
- **VM ID**: 500 (or your choice)
- **Name**: gaming-windows
- **Resource Pool**: (optional)

### 3.2 OS Tab
- **ISO Image**: Win11_25H2_English_x64.iso
- **Type**: Microsoft Windows
- **Version**: 11/2022

### 3.3 System Tab
- **BIOS**: OVMF (UEFI)
- **Machine**: q35
- **Add EFI Disk**: Yes (local-lvm)
- **Add TPM**: Yes (TPM State: local-lvm, Version: v2.0)
- **SCSI Controller**: VirtIO SCSI single

### 3.4 Disks Tab
- **Bus/Device**: SCSI 0 (VirtIO Block)
- **Storage**: local-lvm
- **Disk size**: 100 GiB (or more for games)
- **Cache**: Write back
- **Discard**: Yes
- **SSD emulation**: Yes

### 3.5 CPU Tab
- **Sockets**: 1
- **Cores**: 8 (or 6-12, leave some for host)
- **Type**: host

### 3.6 Memory Tab
- **Memory**: 16384 MiB (16 GB, adjust based on available RAM)
- **Minimum memory**: Leave blank (ballooning disabled by default)

### 3.7 Network Tab
- **Bridge**: vmbr0
- **Model**: VirtIO (paravirtualized)
- **Firewall**: (optional)

### 3.8 Confirm and Create
- Review settings and click **Finish**

## Part 4: Add GPU Passthrough to VM

### 4.1 Add PCI Device (GPU)

In Proxmox GUI:
1. Select VM 500 → Hardware → Add → PCI Device
2. **Device**: Select your GPU (e.g., 0000:3e:00.0)
3. **All Functions**: Yes (passes both GPU and audio)
4. **Primary GPU**: No (not yet)
5. **PCI-Express**: Yes
6. **ROM-Bar**: Yes

### 4.2 Add Second CD/DVD Drive for VirtIO ISO

1. Hardware → Add → CD/DVD Drive
2. **Bus/Device**: IDE 2 (or SATA 1)
3. **Storage**: local
4. **ISO image**: virtio-win.iso

### 4.3 Set Boot Order

1. Options → Boot Order
2. Enable: scsi0 (main disk), ide2 (Windows ISO)
3. Disable: net0
4. Order: ide2 first (for installation), then scsi0

### 4.4 Connect Physical Monitor to GPU

**Important**: For initial setup, connect a physical monitor to the GPU's output ports. This is required because the GPU is passed through directly to the VM.

## Part 5: Install Windows 11

### 5.1 Start VM and Boot from ISO

1. Start VM 500
2. Watch the physical monitor (VM will display there, not in Proxmox console)
3. Boot from Windows 11 installation media

### 5.2 Add USB Keyboard and Mouse (if needed)

If you can't control the VM via Proxmox console:

1. While VM is running: Hardware → Add → USB Device
2. **Use USB Vendor/Device ID**: Yes
3. Select your keyboard
4. Click Add
5. Repeat for mouse

Alternative: Use a USB keyboard/mouse plugged directly into the host

### 5.3 Load VirtIO SCSI Driver

When Windows installer shows no disks:

1. Click **Load driver**
2. Click **Browse**
3. Navigate to the VirtIO CD (usually D: or E:)
4. Browse to: `vioscsi\w11\amd64`
5. Click **OK**
6. Select "Red Hat VirtIO SCSI controller"
7. Click **Next**

Disk should now appear.

### 5.4 Complete Windows Installation

1. Partition the disk (delete all partitions, create new)
2. Install Windows
3. Wait for installation and reboots

### 5.5 Install VirtIO Network Driver

After Windows boots to desktop:

**Option A**: Install individual driver
1. Open File Explorer
2. Navigate to VirtIO CD drive
3. Go to `NetKVM\w11\amd64`
4. Right-click `netkvm.inf` → Install

**Option B**: Install all drivers at once
1. Navigate to VirtIO CD drive
2. Run `virtio-win-guest-tools.exe`
3. Install all components

Network should now work.

## Part 6: Install NVIDIA Drivers

### 6.1 Download NVIDIA GeForce Drivers

From another computer or in the VM (if network is working):
- Go to https://www.nvidia.com/download/index.aspx
- Select your GPU model (e.g., RTX 3080 Ti)
- Download GeForce Game Ready Driver

### 6.2 Install Drivers in VM

1. Run the NVIDIA installer
2. Select **Custom** installation
3. Perform a **Clean installation**
4. Reboot when prompted

### 6.3 Verify GPU is Working

1. Right-click desktop → NVIDIA Control Panel
2. Check that GPU is detected
3. Open Device Manager → Display adapters (should show RTX 3080 Ti)

## Part 7: Switch to GPU-Only Mode

Once NVIDIA drivers are installed and working:

### 7.1 Enable Primary GPU

1. Shut down the VM
2. Hardware → Select the PCI Device (GPU)
3. Edit → **Primary GPU**: Yes

### 7.2 Disable Virtual Display

1. Hardware → Display
2. Edit → Set to **none**

### 7.3 Start VM

VM will now output **only** to the physical monitor connected to the GPU. Proxmox console will be blank.

## Part 8: Install Sunshine for Streaming

### 8.1 Download Sunshine

In Windows VM:
- Go to https://github.com/LizardByte/Sunshine/releases
- Download latest Windows installer (e.g., `sunshine-windows-installer.exe`)

### 8.2 Install Sunshine

1. Run the installer
2. Accept defaults
3. Complete installation
4. Sunshine will start automatically

### 8.3 Configure Sunshine

1. Open browser in VM: https://localhost:47990
2. Set username/password for Sunshine web UI
3. Note the VM's IP address (e.g., 10.150.10.175)

### 8.4 Configure Windows Firewall

Allow Sunshine through firewall:
1. Settings → Privacy & Security → Windows Security → Firewall & network protection
2. Allow an app through firewall
3. Find Sunshine and enable for Private/Public networks

## Part 9: Connect with Moonlight

### 9.1 Install Moonlight on Client

On your laptop/client device:
- Download from https://moonlight-stream.org
- Install for your OS (Windows/macOS/Linux/Android/iOS)

### 9.2 Connect to Sunshine

1. Open Moonlight
2. Click **Add PC Manually**
3. Enter VM IP address (e.g., 10.150.10.175)
4. Enter the PIN shown in Sunshine web UI
5. Connection should succeed

### 9.3 Test Streaming

1. In Moonlight, select the PC
2. Start "Desktop" stream
3. You should see the Windows desktop
4. Test mouse/keyboard input

## Part 10: Install Steam and Games

### 10.1 Install Steam

1. In Windows VM: https://store.steampowered.com/about/
2. Download and install Steam
3. Log in with your account

### 10.2 Add Steam to Sunshine

Sunshine should auto-detect Steam. If not:
1. Sunshine web UI → Applications
2. Add new application
3. Command: `C:\Program Files (x86)\Steam\steam.exe`

### 10.3 Test Gaming

1. Install a game (e.g., Portal)
2. Launch via Moonlight
3. Select game from Sunshine app list
4. Verify smooth gameplay

## Troubleshooting

### VM Won't Start After Adding GPU

**Symptom**: VM fails to start with GPU attached
**Cause**: GPU not properly bound to vfio-pci on host
**Fix**: Verify `lspci -nnk -d <vendor>:<device>` shows "Kernel driver in use: vfio-pci"

### No Display on Physical Monitor

**Symptom**: Monitor shows "No signal" when VM starts
**Causes**:
1. GPU still bound to host driver (fix: recheck Part 1)
2. Monitor connected to wrong port
3. VM hasn't booted yet (wait 30-60 seconds)

**Fix**: Check GPU driver binding, try different monitor cable/port

### Windows Installer Shows No Disks

**Symptom**: Can't select installation target
**Cause**: VirtIO SCSI driver not loaded
**Fix**: Load driver from virtio-win.iso (see Part 5.3)

### No Network in Windows

**Symptom**: No internet connection after Windows install
**Cause**: VirtIO network driver not installed
**Fix**: Install from virtio-win.iso (see Part 5.5)

### Moonlight Can't Find PC

**Symptoms**:
- Sunshine not discovered automatically
- Manual connection times out

**Fixes**:
1. Verify Sunshine is running in VM (https://localhost:47990)
2. Check Windows Firewall allows Sunshine
3. Verify VM has network (ping from host: `ping <vm-ip>`)
4. Try manual connection with IP address
5. Check both devices on same network/VLAN

### Poor Gaming Performance

**Causes**:
1. CPU cores overcommitted (fix: reduce VM cores, leave some for host)
2. RAM overcommitted (fix: reduce VM RAM allocation)
3. Disk I/O bottleneck (fix: use local storage, enable SSD emulation, cache=writeback)
4. Network congestion (fix: use wired ethernet, check bandwidth)

**Optimize**:
- VM uses local-lvm storage (not NFS/Ceph for gaming VM disk)
- CPU type set to "host"
- Enable "PCI-Express" on GPU passthrough
- Enable NUMA if multi-socket system

### VM Crashes or Blue Screens

**Causes**:
1. NVIDIA driver version mismatch
2. Insufficient RAM
3. Unstable GPU overclock

**Fixes**:
1. Reinstall NVIDIA drivers (clean install)
2. Increase VM RAM allocation
3. Reset GPU clocks to default
4. Check host logs: `journalctl -u pve-guests -f`

### Code 43 Error in Device Manager

**Symptom**: GPU shows "Error 43" in Device Manager
**Causes**:
1. NVIDIA detects virtualization (older drivers)
2. Incorrect VM configuration

**Fixes**:
1. Use latest NVIDIA drivers (newer versions ignore VM detection)
2. Ensure `args: -cpu host,kvm=off` in VM config (not needed with modern drivers)
3. Verify BIOS is OVMF (UEFI), not SeaBIOS
4. Ensure "Primary GPU" is enabled after driver install

## VM Configuration Reference

Final `/etc/pve/qemu-server/500.conf` example:

```
agent: 1
bios: ovmf
boot: order=scsi0;ide2
cores: 8
cpu: host
efidisk0: local-lvm:vm-500-disk-0,efitype=4m,pre-enrolled-keys=1,size=4M
hostpci0: 0000:3e:00,pcie=1,x-vga=1
ide0: local:iso/Win11_25H2_English_x64.iso,media=cdrom,size=6234988K
ide2: local:iso/virtio-win.iso,media=cdrom,size=612812K
machine: q35
memory: 16384
meta: creation-qemu=9.0.2,ctime=1729728342
name: gaming-windows
net0: virtio=BC:24:11:XX:XX:XX,bridge=vmbr0,firewall=1
numa: 0
ostype: win11
scsi0: local-lvm:vm-500-disk-1,discard=on,iothread=1,size=100G,ssd=1
scsihw: virtio-scsi-single
smbios1: uuid=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
sockets: 1
tpmstate0: local-lvm:vm-500-disk-2,size=4M,version=v2.0
usb0: host=046d:c52b
usb1: host=1c4f:0002
vmgenid: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

Key parameters:
- `hostpci0`: GPU passthrough with PCIe, primary GPU (`x-vga=1`)
- `cpu: host`: Best performance
- `machine: q35`: Required for PCIe passthrough
- `bios: ovmf`: UEFI required for Windows 11 and modern GPU passthrough
- `tpmstate0`: TPM 2.0 required for Windows 11
- `scsi0`: VirtIO SCSI with discard, iothread, SSD emulation

## Performance Tuning

### CPU Pinning (Advanced)

For best performance, pin VM cores to specific host CPUs:

```bash
# Find CPU topology
lscpu -e

# Edit VM config
qm set 500 -args "-cpu host,kvm=off -smp 8,sockets=1,cores=8,threads=1"
```

### Hugepages (Advanced)

Reduce memory overhead:

```bash
# In /etc/default/grub:
GRUB_CMDLINE_LINUX_DEFAULT="... hugepagesz=1G hugepages=32"

# Update grub and reboot
update-grub
reboot

# In VM config:
qm set 500 -hugepages 1024
```

### I/O Thread Optimization

Already enabled with `iothread=1` on scsi0. Verify in VM config.

## Ansible Automation (Future)

To deploy this setup to multiple Proxmox hosts, create an Ansible playbook:

**Tasks**:
1. Configure host (GRUB, modules, blacklist, vfio binding)
2. Reboot host
3. Download ISOs
4. Create VM via Proxmox API
5. Add GPU passthrough
6. Template Windows installation (after initial setup)

**Variables**:
- `gpu_pci_id`: PCI address of GPU
- `gpu_vendor_device_ids`: Vendor:device IDs for vfio binding
- `vm_id`: Target VM ID
- `vm_cores`, `vm_memory`, `vm_disk_size`: Resource allocation

## References

- Proxmox GPU Passthrough Guide: https://pve.proxmox.com/wiki/PCI_Passthrough
- Sunshine Documentation: https://docs.lizardbyte.dev/projects/sunshine/
- Arch Wiki PCI Passthrough: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
- r/Proxmox GPU Passthrough Megathread: https://www.reddit.com/r/Proxmox/

## Deployment Checklist

- [ ] Host IOMMU enabled in BIOS
- [ ] Host GRUB configured with iommu parameters
- [ ] VFIO modules loaded (`/etc/modules`)
- [ ] NVIDIA drivers blacklisted (`/etc/modprobe.d/blacklist.conf`)
- [ ] GPU bound to vfio-pci (`/etc/modprobe.d/vfio.conf`)
- [ ] initramfs updated, host rebooted
- [ ] GPU shows vfio-pci driver in `lspci -nnk`
- [ ] Windows 11 ISO downloaded
- [ ] VirtIO drivers ISO downloaded
- [ ] VM created with UEFI, Q35, TPM 2.0
- [ ] GPU added as PCI device with PCIe enabled
- [ ] Physical monitor connected to GPU
- [ ] Windows 11 installed with VirtIO drivers
- [ ] NVIDIA drivers installed in Windows
- [ ] VM switched to GPU-only mode (Primary GPU enabled, Display=none)
- [ ] Sunshine installed and configured
- [ ] Moonlight tested and working
- [ ] Steam installed
- [ ] Gaming tested successfully

## Next Steps After POC

1. Document game-specific configurations
2. Create Windows VM template with drivers pre-installed
3. Build Ansible playbook for multi-host deployment
4. Deploy to pve008 (2x RTX 3080 gaming host)
5. Test co-op gaming between systems
6. Set up automated backups of gaming VMs
7. Configure resource scheduling (GPU available for AI when not gaming)

---

**Status**: Tested and working on pve007 (2025-10-24)
**Hardware**: AMD Ryzen 9 5900X, NVIDIA RTX 3080 Ti, 64GB RAM
**Software**: Proxmox VE 8.x, Windows 11 25H2, NVIDIA 566.03, Sunshine 2024.1001.19XXXX
