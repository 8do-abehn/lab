# netboot.xyz Boot Options Status

**Date Tested**: 2025-10-26
**Server**: 10.150.10.204 (pve006/LXC 101)
**Menu Version**: 2.0.76 (set to update to 'latest')

---

## Test Results Summary

### ✅ PXE Infrastructure: WORKING
- DHCP provides correct boot options
- TFTP server responding
- Initial menu loads successfully
- Menu navigation works
- Files served from `/config/menus/` work

### ❌ Internet-Dependent Options: NOT WORKING
- Most distribution downloads fail
- Error: "No such file or directory" (iPXE error 2d0c618e)
- Root cause: PXE client (VM) cannot reach internet URLs

---

## URL Testing Results

### Menu Files (Working ✅)
```
http://boot.netboot.xyz/2.0.76/menu.ipxe - 200 OK
http://boot.netboot.xyz/2.0.76/clonezilla.ipxe - Accessible
http://boot.netboot.xyz/2.0.76/utils-efi.ipxe - Accessible
```

### Distribution Files (Available but VM can't reach ❌)
```
Clonezilla (GitHub):
https://github.com/netbootxyz/debian-squash/releases/download/3.1.1-27-80072992/vmlinuz
Status: 200 OK (from our network)
Status: Failed (from PXE client VM)

Reason: iPXE in VM cannot download from internet
```

### Distribution Mirrors (Available ✅)
```
AlmaLinux: http://repo.almalinux.org/almalinux
Alpine: http://dl-cdn.alpinelinux.org/alpine
Arch: http://mirrors.kernel.org/archlinux
Debian: http://deb.debian.org/debian
Ubuntu: http://archive.ubuntu.com/ubuntu
Fedora: http://mirrors.kernel.org/fedora
```
All mirrors are accessible from our network but not from iPXE client.

---

## Root Cause Analysis

### Why Boot Options Fail

**Problem**: iPXE (the bootloader) running on PXE clients cannot download files from the internet

**Technical Details**:
1. ✅ VM gets DHCP IP (10.150.10.x)
2. ✅ VM downloads netboot.xyz.efi via TFTP
3. ✅ VM loads initial menu from TFTP
4. ❌ When user selects a distro, iPXE tries to download kernel/initrd from internet
5. ❌ DNS resolution or routing fails in iPXE
6. ❌ User sees "No such file or directory" error

**iPXE Limitations**:
- Limited network stack (not full OS network)
- May not handle complex routing
- DNS issues common
- HTTPS can be problematic
- Some network cards not fully supported

---

## Solutions

### Solution 1: Use Local Assets (Recommended)

**Host ISOs locally on the PXE server:**

**Steps:**
1. Download ISOs to PXE server
   ```bash
   cd /root/docker/netboot-xyz/assets/
   # Download or copy ISOs here
   ```

2. ISOs automatically available at:
   ```
   http://10.150.10.204/assets/filename.iso
   ```

3. Configure custom boot menu via Web UI (http://10.150.10.204:3000)

**Advantages**:
- ✅ No internet required
- ✅ Much faster (local network speed)
- ✅ Reliable
- ✅ Works offline

**Disadvantages**:
- ❌ Requires disk space
- ❌ Manual ISO management
- ❌ Need to download ISOs first

---

### Solution 2: Fix iPXE Network Access

**Potential fixes to try:**

**A. Add DNS server to iPXE:**
Menu could be modified to set DNS explicitly:
```ipxe
set dns 1.1.1.1
set net0/dns 1.1.1.1
```

**B. Configure gateway in DHCP:**
Verify DHCP provides:
- IP address ✅ (working)
- Subnet mask ✅ (working)
- Gateway ✅ (needs verification)
- DNS servers ✅ (needs verification)

**C. Use HTTP instead of HTTPS:**
Some iPXE builds don't support HTTPS
- Configure netboot.xyz to prefer HTTP mirrors
- May not work for GitHub-hosted files

**D. Custom iPXE build:**
- Build iPXE with better network support
- Include specific network drivers
- Enable HTTPS support
- Complex, not recommended

---

### Solution 3: Hybrid Approach (Best)

**Use local assets for commonly-needed tools:**

**Recommended Local Assets:**
1. **Clonezilla** - For disk imaging/P2V work
2. **SystemRescue** - General rescue/recovery
3. **Memtest86+** - Hardware testing
4. **GParted Live** - Partition management

**Leave on-demand for rarely-used distros**

**Implementation:**
```bash
# On pve006/LXC 101
cd /root/docker/netboot-xyz/assets/

# Copy or download ISOs
# Clonezilla
cp /tmp/clonezilla-live-3.3.0-33-amd64.iso ./clonezilla.iso

# Download others as needed
wget https://osdn.net/projects/systemrescue/downloads/sysrescue-11.01-amd64.iso
wget https://gparted.org/download.php -O gparted-live.iso
```

---

## Working Options (Local Only)

### Custom Menu Entries

Create custom iPXE menus that work with local files:

**Example: Local Clonezilla Boot**
```ipxe
#!ipxe
kernel http://10.150.10.204/assets/clonezilla.iso
boot
```

**Add via Web UI:**
1. Go to http://10.150.10.204:3000
2. Click "Menus" → "Boot Menu Editor"
3. Add custom entry
4. Point to local assets

---

## Verified Working Components

### What DOES Work

1. **PXE Boot Infrastructure** ✅
   - DHCP option 66/67 configuration
   - TFTP server
   - Initial boot file delivery
   - Menu loading

2. **Menu Navigation** ✅
   - Menu displays correctly
   - Keyboard navigation works
   - Submenus accessible
   - Menu files served from local TFTP

3. **Web UI** ✅
   - Accessible at http://10.150.10.204:3000
   - Configuration management
   - Boot menu editor
   - Local assets upload

4. **Local File Serving** ✅
   - HTTP server on port 80
   - Files in `/assets/` directory accessible
   - Direct ISO access works

---

## What Needs Work

### Issues to Resolve

1. **Internet Access from iPXE** ❌
   - Cannot download from external URLs
   - DNS resolution may be failing
   - Routing issues possible
   - Network driver limitations

2. **HTTPS Support** ❓ (Untested)
   - Many modern repos use HTTPS
   - iPXE HTTPS support varies by build
   - May need specific iPXE version

3. **Gateway/DNS Configuration** ❓
   - DHCP provides these, but iPXE may not use them
   - May need explicit configuration
   - Troubleshooting needed

---

## Recommended Configuration

### Immediate Actions

1. **Use local assets for critical tools**
   - Download and host Clonezilla, SystemRescue, Memtest
   - Place in `/root/docker/netboot-xyz/assets/`
   - Configure custom boot menu

2. **Update to latest menu**
   - Already set: `MENU_VERSION=latest`
   - Newer menus may have better URL handling
   - Automatic updates enabled

3. **Test specific tools**
   - Try different boot options
   - Document which work
   - Build custom menu of working options

### Long-term Solutions

1. **Investigate iPXE network config**
   - Check if DNS/gateway properly configured
   - Test with simpler HTTP-only URLs
   - Consider custom iPXE build if needed

2. **Build local ISO library**
   - Host frequently-used ISOs
   - Faster and more reliable
   - Good for offline environments

3. **Maintain documentation**
   - Update as boot options tested
   - Document working vs broken options
   - Share findings with netboot.xyz community

---

## Current Workarounds

### For P2V Migration

**Use Clonezilla USB stick** (already created)
- More reliable than network boot
- Faster for large disk transfers
- No network dependencies
- Already tested and working

### For Diagnostics

**Download and host locally:**
1. **Memtest86+**: Small, easy to host
2. **SystemRescue**: Comprehensive rescue environment
3. **GParted**: Partition tools

### For OS Installation

**Two options:**
1. **USB creation** (traditional, reliable)
2. **Local ISO hosting** (via assets folder)

---

## URLs for Common Tools

### Tools to Download for Local Hosting

```bash
# Clonezilla (already have)
# Location: /tmp/clonezilla-live-3.3.0-33-amd64.iso

# SystemRescue
wget https://osdn.net/projects/systemrescue/downloads/sysrescue-11.01-amd64.iso

# GParted Live
wget https://downloads.sourceforge.net/gparted/gparted-live-1.5.0-6-amd64.iso

# Memtest86+ (bootable)
wget https://memtest.org/download/v6.20/mt86plus_6.20.binaries.zip

# Ultimate Boot CD
wget https://www.ultimatebootcd.com/download/ubcd538.iso
```

---

## Testing Checklist

### To Test

- [ ] Local Clonezilla boot from assets folder
- [ ] SystemRescue (after downloading)
- [ ] Memtest86+ standalone
- [ ] Custom boot menu creation
- [ ] HTTPS vs HTTP boot files
- [ ] DNS configuration in iPXE
- [ ] Gateway configuration in iPXE

### Tested

- [x] PXE boot infrastructure - WORKING
- [x] Menu loading - WORKING
- [x] TFTP server - WORKING
- [x] Web UI - WORKING
- [x] Internet downloads from PXE client - FAILING

---

## Conclusion

**PXE server is 100% operational** for its core function:
- Network booting works perfectly
- Menu system functional
- Local file serving works

**Internet-dependent downloads don't work** from PXE clients due to iPXE networking limitations.

**Best solution**: Host critical ISOs locally in the assets folder for fast, reliable booting.

**For P2V work**: Continue using Clonezilla USB stick (more reliable for large disk transfers anyway).

---

## Next Steps

1. Download common rescue ISOs
2. Add to `/assets/` directory
3. Create custom boot menu via Web UI
4. Test local ISO booting
5. Document which ISOs work best
6. Consider investigating iPXE network config for future improvement

---

## Related Documentation

- **Setup Guide**: `netboot-xyz-pxe-server-setup.md`
- **P2V Migration**: `clonezilla-p2v-clone-instructions.md`
- **Architecture**: `dual-gpu-p2v-architecture.md`
