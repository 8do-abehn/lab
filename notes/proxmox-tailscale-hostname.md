# Proxmox Tailscale Hostname Configuration

## Overview
Configure Proxmox to respond to Tailscale MagicDNS hostname `pve.taile975f.ts.net`.

## Prerequisites
- Tailscale installed and running on Proxmox server
- SSH access to Proxmox server

## Configuration Steps

### 1. Set Tailscale Hostname

```bash
tailscale set --hostname pve
```

This makes the server accessible at `pve.taile975f.ts.net` via Tailscale MagicDNS.

### 2. Verify Hostname

```bash
tailscale status
```

Test from another Tailnet device:
```bash
ping pve.taile975f.ts.net
```

### 3. Configure Proxmox to Accept Tailscale Hostname

#### Option A: Using /etc/default/pveproxy

Edit the pveproxy configuration:

```bash
vi /etc/default/pveproxy
```

Add these lines:

```bash
# Allow access via Tailscale hostname
ALLOW_FROM="all"
POLICY_DOMAIN="pve.taile975f.ts.net"
```

#### Option B: Using /etc/pve/local/pveproxy.conf

Create the local configuration directory and file:

```bash
mkdir -p /etc/pve/local
vi /etc/pve/local/pveproxy.conf
```

Add:

```
ALLOW_FROM: all
```

### 4. Restart pveproxy Service

```bash
systemctl restart pveproxy
```

### 5. Verify Service Status

```bash
systemctl status pveproxy
```

### 6. Test Access

From another device on your Tailnet:

```
https://pve.taile975f.ts.net:8006
```

## Notes

- You may still see a certificate warning since the SSL certificate is for the original hostname
- To eliminate certificate warnings, you would need to configure a Let's Encrypt certificate for the Tailscale hostname
- The connection will work despite the certificate warning

## Security Considerations

- `ALLOW_FROM="all"` allows connections from any IP
- Since this is behind Tailscale, only devices on your Tailnet can reach it
- Consider more restrictive policies if needed

## Troubleshooting

If access doesn't work:

1. Check pveproxy is running: `systemctl status pveproxy`
2. Check pveproxy logs: `journalctl -u pveproxy -f`
3. Verify Tailscale connectivity: `tailscale status`
4. Verify firewall rules allow port 8006
5. Check configuration files for syntax errors

## References

- Tailscale MagicDNS: https://tailscale.com/kb/1081/magicdns/
- Proxmox VE Documentation: https://pve.proxmox.com/wiki/Main_Page
