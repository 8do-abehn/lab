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

## Measured UPS Values (pve01, 2026-09-08)

Read directly off the UPS over the 940-0024C cable:

| Register | Value | Notes |
|----------|-------|-------|
| Model | SMART-UPS 2200 | firmware 80.11.D |
| Load | 31.2% | roughly 690 VA of 2200 VA |
| Runtime remaining | 7 min | at the above load, battery at 100% |
| Battery | 55.05 V (48 V nominal) | float voltage, last replaced 01/24/25 |
| Low-battery warning | 2 min as shipped | the `q` register; no longer what triggers LB, see below |
| Shutdown threshold | 0% | UPS-side threshold is disabled |
| Internal temp | 34.2 C | |

The 7 minute figure above is the UPS's own estimator, not a measured discharge, and
it is not trustworthy. See the next section.

## Who decides "low battery"

Since #536, **NUT decides, not the UPS**. The role writes this into the `[myups]`
section of `ups.conf`:

```
ignorelb
override.battery.runtime.low = -1
override.battery.charge.low = <ups_charge_low>
```

`ignorelb` makes the driver discard the UPS's own LB flag and re-derive LB on every
poll from `battery.charge < battery.charge.low OR battery.runtime < battery.runtime.low`.
Pinning `battery.runtime.low` to -1 makes the runtime half unsatisfiable, leaving
charge as the only trigger. See `man apcsmart`, section "IGNORING LB STATE".

Why: the pack was swapped to LiFePO4 on 01/24/25, but the UPS is from 2000 and
models capacity for lead acid, so its runtime estimate is fiction. On 2026-10-02 the
estimate had decayed to `battery.runtime.low`, the UPS latched LB at 100% charge on
line power, and the first momentary transfer to battery read as OB+LB and shut pve01
down with mains present the whole time. Deriving LB in NUT also means LB clears again
on the next poll instead of latching. Full writeup in #492 and #536.

`ups_charge_low` is **provisional and makes no safety claim**. `battery.charge` is
derived from pack voltage through a lead-acid curve, and LiFePO4's curve is flat, so
the reading stays high for most of the discharge and then collapses. The value is
derived from constraints, not measured, and promises no particular warning time. See
the comment on the variable in `roles/nut/defaults/main.yml`, and #487 for the
measurement that should replace it.

### The UPS-side NVRAM threshold is gone

The role used to write `battery.runtime.low` into UPS NVRAM with
`upsrw -s battery.runtime.low=<ups_lowbatt_runtime>`. Those two tasks and the
variable were removed with #536.

They are incompatible with `ignorelb`, not merely redundant. `override.*` marks a
variable `ST_FLAG_IMMUTABLE` (`drivers/main.c`, `storeval`), the driver then never
publishes it `RW`, and `upsd` answers any `SET` on it with `ERR READONLY`. Left in
place the read would return `-1`, the `!= ups_lowbatt_runtime` guard would be true on
every run, and the `upsrw` would fire and fail every deploy.

The UPS's own NVRAM value still decides when the unit beeps. It no longer influences
any shutdown decision.

### Read-back check

The driver's startup check (`drivers/main.c`) is satisfied if **either** the charge
pair or the runtime pair is present. `override.battery.runtime.low = -1` supplies the
runtime pair, so the driver starts happily even if `override.battery.charge.low`
never took effect, and `battery.runtime < -1` is never true. That failure mode is
silent and total: LB simply never fires.

Both `roles/nut/tasks/server.yml` and `verify_nut.yml` therefore read
`battery.charge.low` back out of the running driver and fail loudly if it is missing
or wrong. The role-side assert is skipped in check mode, where no config has been
written yet.

## Shutdown Timeline

### Detection Phase
- **POLLFREQALERT 5** - Checks UPS every **5 seconds** when on battery
- UPS status change detected within **5 seconds**

### Shutdown Trigger
- Shutdown initiates when the UPS is on battery (OB) **and** low battery (LB)
- LB comes from the driver comparing `battery.charge` against `ups_charge_low`,
  not from the UPS

### Execution Phase
- **FINALDELAY 5** - **5 second** delay before shutdown command
- **SHUTDOWNCMD** - Immediate shutdown (no additional delay with `+0`)

### Total Time
**From "low battery" signal to shutdown: ~10 seconds**

## Current Behavior Flow

1. **Power loss** → UPS switches to battery
2. **Wait period** → `battery.charge` falls to `ups_charge_low`
3. **Detection** → the driver sets LB and upsmon sees OB+LB within 5 seconds
4. **Delay** → 5 second FINALDELAY
5. **Shutdown** → Immediate system halt

## Alternative: Time-Based Shutdown

A charge threshold was chosen over `upssched` because `upsmon` runs `NOTIFYCMD` as
its unprivileged child, so the `upsmon -c fsd` in an upssched command script cannot
signal the root parent that performs the shutdown. Making that work needs
`RUN_AS_USER root` in `upsmon.conf`, which runs the network-facing upsd client as
root on every node.

A time-on-battery watchdog would sidestep the charge-reading problem entirely, and
#536 flags it as worth revisiting. If you want shutdown keyed to time on battery
instead:

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
- Ensure the low battery threshold is set appropriately
- Generic advice is 2-3 minutes runtime remaining or 20-30% battery, but it does not
  apply to this unit: see "Who decides low battery" above for why the percentage
  reading is distorted here

### For Maximum Runtime (Ride Through Short Outages)
- Implement time-based shutdown with upssched
- Set timer to 5-10 minutes to allow power to return
- Only shutdown if outage persists

### For Graceful Multi-Host Shutdown
- Increase HOSTSYNC to 30-60 seconds
- Ensure all hosts can complete their shutdown procedures
- Consider staggered shutdown (VMs before hosts)
