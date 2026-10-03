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

There are two independent paths, and in practice the watchdog fires first.

1. **Time on battery.** `nut-onbatt-watchdog` calls `upsmon -c fsd` after
   `ups_onbatt_shutdown_delay` seconds (default 60) continuously on battery. See
   "Time-on-battery watchdog" below.
2. **OB + LB.** `upsmon` shuts down when the UPS is on battery and low battery. LB
   comes from the driver comparing `battery.charge` against `ups_charge_low`, not
   from the UPS.

Path 2 is the backstop. Its threshold is distorted (see above), so path 1 is what
should normally act, on the one signal the hardware cannot misreport.

### Execution Phase
- **FINALDELAY 5** - **5 second** delay before shutdown command
- **SHUTDOWNCMD** - Immediate shutdown (no additional delay with `+0`)

### Total Time
**From "low battery" signal to shutdown: ~10 seconds**

## Current Behavior Flow

1. **Power loss** → UPS switches to battery, `ups.status` gains OB
2. **Wait period** → the watchdog counts 60 seconds of uninterrupted OB. Line power
   returning at any point resets it and nothing happens.
   (Backstop: if the watchdog is not running, `battery.charge` falling below
   `ups_charge_low` sets LB and upsmon reacts to OB+LB instead.)
3. **FSD** → `upsmon -c fsd` sets the flag on upsd, HOSTSYNC releases, POWERDOWNFLAG
   is written
4. **Delay** → 5 second FINALDELAY
5. **Shutdown** → `SHUTDOWNCMD` halts the host
6. **Power cut** → the systemd-shutdown hook runs `upsdrvctl shutdown`, then waits
   `POWEROFF_WAIT` and force-reboots if the UPS did not cut the load

## Time-on-battery watchdog

`nut-onbatt-watchdog.service` on the `nut_server` host polls `ups.status` and
requests a coordinated shutdown once the UPS has been continuously on battery for
`ups_onbatt_shutdown_delay` seconds (default 60). Any observation of line power
resets the timer. Script: `roles/nut/templates/nut-onbatt-watchdog.sh.j2`.

This exists because elapsed time is the only signal this UPS cannot distort. Both
`battery.runtime` and `battery.charge` are derived from a lead-acid capacity model
while the pack has been LiFePO4 since 01/24/25.

It is a long-running service with its own sleep loop rather than a systemd timer. A
timer would have to persist "how long have we been on battery" in a state file
between invocations, which then needs invalidating on boot and still cannot survive
a clock step. Elapsed time held in memory by one process has neither problem, and
the process dying resets it to the safe value by construction.

The trigger action is `upsmon -c fsd`, never a bare `shutdown`. FSD is what sets the
flag on upsd, releases `HOSTSYNC`, runs `SHUTDOWNCMD`, writes `POWERDOWNFLAG` and
lets the systemd-shutdown hook command the UPS to cut the load. A plain `shutdown`
would halt the host with the UPS still powered, which is the two minute bounce
recorded in #536.

Fail-safe behaviour: if `upsc` fails, or returns anything that is not a plausible
status string, the watchdog logs and does nothing. It never shuts down on an
unreadable status. A dropped poll does not reset the timer either, so one bad
sample during a real outage cannot buy the UPS another full threshold. It fires at
most once per boot and the unit does not restart on its clean exit.

`ups_onbatt_shutdown_delay` is provisional and deliberately shorter than any
plausible real runtime. #487's measurement supplies the real number.

### Why not upssched

`upsmon` runs `NOTIFYCMD` as its unprivileged child, so the `upsmon -c fsd` in an
upssched command script cannot signal the root parent that performs the shutdown.
Making that work needs `RUN_AS_USER root` in `upsmon.conf`, which runs the
network-facing upsd client as root on every node. The watchdog is root-owned from
the start and sidesteps the whole question, which is why that is no longer a
blocker.

### Adding a voltage threshold later

`ups_is_critical()` in the watchdog script is the single place the decision is made,
and the only place in this role where a battery voltage test could ever live.
Adding one means adding a condition to that function; nothing else changes. It is
deliberately not implemented now, because no trustworthy voltage threshold exists
for this pack yet.

## Power-race avoidance

`nut.conf` sets `POWEROFF_WAIT` (`ups_poweroff_wait`, default 120 seconds).

`/lib/systemd/system-shutdown/nutshutdown` runs `upsdrvctl shutdown` and then, if
`POWEROFF_WAIT` is set, sleeps that long and force-reboots. Unset, it logs
"POWEROFF_WAIT is not configured at this time" and leaves the host halted
indefinitely whenever the UPS declines to cut the load, which is what happens if
mains returns mid-shutdown.

That branch was unreachable until #536: FSD was denied, so `POWERDOWNFLAG` was never
written, `upsmon -K` was always false and the entire hook was dead code. Granting
FSD makes it live, so the value had to be set in the same change.

120 rather than the upstream example of 15m: `ups.delay.shutdown` on this unit is
`020`, so if the UPS intends to honour the command it has done so around 20 seconds
in and the host is already dark. The upstream example assumes the sleep should last
long enough to flatten the battery, which made sense when the only trigger was a
genuinely flat pack. Our trigger is a 60 second timer, so the pack may still be
nearly full, and the only reason the UPS would refuse is that mains is back.
Sleeping 15 minutes would keep a healthy node dark for no reason.

## The upsd listener

`upsd.conf` always listens on `127.0.0.1`, because pve01's own upsmon and the
on-battery watchdog connect via `localhost`. `ups_listen_address` adds a second
`LISTEN` when it is not loopback. `inventory/group_vars/nut.yml` sets it to
`ups_server_ip`, the management VLAN address pve02/pve03 dial.

`server.yml` asserts that a loopback-only listener and a non-empty
`nut_netclients` never coexist, because that combination fails silently: the
netclients simply never connect and FSD reaches nobody.

## Why pve02 and pve03 must be netclients

pve02, pve03 and the network gear are all on this UPS's battery outlets. Once FSD
works, pve01's shutdown hook tells the UPS to cut its output about 20 seconds after
pve01 halts. A host on the UPS that is not enrolled gets no warning and loses power
hard. With Ceph on all three nodes, that is the worst outcome available.

Enrolled, they receive FSD first. pve01 waits up to `HOSTSYNC` (15s) for them to
disconnect, then shuts down itself, and only then is the load cut. Measured clean
shutdowns were ~46s (pve03, 2026-09-22) and ~54s (pve01, 2026-10-02), so the
secondaries get roughly 70s+ against ~46s needed. That margin assumes a clean
shutdown; a guest that hangs on stop (see the node reboot notes on `ct:3102` and
`ceph-fuse`) will still be cut. `ups.delay.shutdown` is writable (020/180/300/600)
if more margin is ever needed, but `ups_poweroff_wait` must then be raised above it.

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
