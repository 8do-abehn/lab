# Add Taildrive to Jellyfin Container

## Summary
Install and configure Taildrive on Jellyfin LXC container (3001) to enable direct media uploads to the library from any Tailscale device.

## Current Setup
- **Container**: LXC 3001 on pve005
- **OS**: Ubuntu 24.04
- **Jellyfin**: Running with AMD GPU passthrough for hardware transcoding
- **Network**: Connected to Tailscale

## Goal
Enable Taildrive share inside the Jellyfin container so media files can be added directly to the library without SSH/SFTP.

## Benefits
- Upload media from laptop/desktop directly to Jellyfin library
- No need for SSH/SFTP transfers
- Integrated with Tailscale authentication
- Simpler workflow for adding new content

## Tasks
- [ ] Install Tailscale in Jellyfin LXC container (if not already present)
- [ ] Enable Taildrive on the container
- [ ] Configure Taildrive share pointing to Jellyfin media library location
- [ ] Set correct permissions for jellyfin user to access Taildrive mount
- [ ] Test upload from laptop to verify files appear in library
- [ ] Configure Jellyfin to auto-scan or trigger library scan on new files
- [ ] Document the setup process

## Technical Notes
- Taildrive mount point should align with Jellyfin's media library paths
- Consider permissions: jellyfin user needs read/write access
- May need to configure LXC container features for FUSE support
- Check if unprivileged container needs additional config for Taildrive

## Resources
- [Taildrive Documentation](https://tailscale.com/kb/1369/taildrive)
- Container ID: 3001
- Host: pve005
- Jellyfin media library location: (document current path)
