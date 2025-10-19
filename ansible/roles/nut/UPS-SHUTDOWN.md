# UPS Shutdown Timing Configuration

## Overview
This documents the shutdown behavior when UPS loses power for Proxmox servers monitored by NUT (Network UPS Tools).

## Current Configuration

```yaml
MONITOR {{ ups_name }}@{{ ups_server_ip }} 1 {{ ups_user }} {{ ups_monitor_pass }} slave
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 30
POWERDOWNFLAG /etc/killpower
RBWARNTIME 10
NOCOMMWARNTIME 300
FINALDELAY 5
```

## Shutdown Timeline

### Detection Phase
- **POLLFREQALERT 5** - Checks UPS every **5 seconds** when on battery
- UPS status change detected within **5 seconds**

### Shutdown Trigger
- Shutdown initiates when UPS reports **"low battery" (LB)** status
- This depends on **UPS-side configuration** (typically 2-5 min runtime remaining or battery % threshold)
- **Note:** This is configured on the UPS itself, not in NUT

### Execution Phase
- **FINALDELAY 5** - **5 second** delay before shutdown command
- **SHUTDOWNCMD** - Immediate shutdown (no additional delay with `+0`)

### Total Time
**From "low battery" signal to shutdown: ~10 seconds**

## Current Behavior Flow

1. **Power loss** → UPS switches to battery
2. **Wait period** → UPS runtime decreases until "low battery" threshold (2-5 min typical)
3. **Detection** → NUT detects LB status within 5 seconds
4. **Delay** → 5 second FINALDELAY
5. **Shutdown** → Immediate system halt

## Alternative: Time-Based Shutdown

If you want faster/more predictable shutdown based on time on battery instead of UPS battery threshold, you can use `upssched`:

### Additional Configuration Required

```yaml
# In upsmon.conf
NOTIFYCMD /usr/sbin/upssched
NOTIFYFLAG ONBATT SYSLOG+EXEC
NOTIFYFLAG LOWBATT SYSLOG+EXEC

# Create upssched.conf
CMDSCRIPT /usr/bin/upssched-cmd
PIPEFN /var/run/nut/upssched.pipe
LOCKFN /var/run/nut/upssched.lock

# Shutdown after 2 minutes on battery
AT ONBATT * START-TIMER onbatt 120
AT ONLINE * CANCEL-TIMER onbatt
AT LOWBATT * EXECUTE forced-shutdown
```

This would trigger shutdown **2 minutes** after power loss, regardless of UPS battery level.

## Key Parameters Explained

| Parameter | Value | Description |
|-----------|-------|-------------|
| POLLFREQ | 5 | Check UPS every 5 seconds (normal operation) |
| POLLFREQALERT | 5 | Check UPS every 5 seconds (on battery/alert) |
| FINALDELAY | 5 | Wait 5 seconds before executing shutdown |
| DEADTIME | 30 | Declare UPS dead after 30 seconds of no communication |
| HOSTSYNC | 15 | Wait 15 seconds for other hosts to logout before shutdown |
| NOCOMMWARNTIME | 300 | Warn after 5 minutes of lost UPS communication |

## Recommendations

### For Fast Shutdown (Minimize Downtime)
- Keep current configuration
- Ensure UPS "low battery" threshold is set appropriately
- Typical: 2-3 minutes runtime remaining or 20-30% battery

### For Maximum Runtime (Ride Through Short Outages)
- Implement time-based shutdown with upssched
- Set timer to 5-10 minutes to allow power to return
- Only shutdown if outage persists

### For Graceful Multi-Host Shutdown
- Increase HOSTSYNC to 30-60 seconds
- Ensure all hosts can complete their shutdown procedures
- Consider staggered shutdown (VMs before hosts)
