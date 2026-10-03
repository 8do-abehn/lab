# UPS Runtime Test Runbook (#487)

A maintenance-window procedure for measuring how long the LiFePO4 pack in the
SU2200 really lasts, and for turning that measurement into
`ups_onbatt_shutdown_delay` and `ups_charge_low`.

Nothing in here is run without an agreed date and explicit go-ahead. It changes
no Ansible-managed setting: the NUT changes during the window are `systemctl stop`
only, and a reboot or deploy re-arms them.

## The hardware, for reference

| Item | Value |
|------|-------|
| UPS | APC SMART-UPS 2200 (SU2200), 1600 W / 2200 VA, manufactured 08/24/00, firmware 80.11.D |
| Pack | 4x BCL-12180 LiFePO4, 12.8 V 18 Ah each, 16S, ~920 Wh, installed 01/24/25 |
| Float | 13.8 V per unit rated (55.2 V string), 55.05 V measured (#539, within spec) |
| On the UPS | pve01, pve02, pve03 and the network gear |
| Cut-off on FSD | UPS drops its output ~20 s after pve01 halts (`ups.delay.shutdown` 020) |

Expected if healthy (arithmetic, not measured): ~36% load is ~580 W out, ~650 to
730 W from the battery, ~12 to 15 A, roughly **60 to 80 minutes** to 48 V. If
`ups.load` turns out to be a percentage of VA rather than W, current is ~16 to 18 A.

## Design: why the cluster comes off the UPS

The obvious options both fail the one hard rule, **nothing in the test may cut
power to a Ceph node unannounced**:

- **Raise `ups_onbatt_shutdown_delay` and discharge the live cluster.** The point
  of the test is to approach the bottom of a pack whose BMS limits the vendor does
  not publish. If a unit's BMS trips, the UPS drops its whole output instantly: all
  three Ceph nodes and the network, with no LB and no shutdown. Raising the delay
  also means two PRs and two deploys from main just to change it and change it back.
- **Migrate or stop workloads first.** All three nodes are on the same UPS, so
  migrating within the cluster moves nothing off it. Stopping guests reduces the
  damage of a hard cut but still hard-cuts three Ceph nodes.
- Even keeping the nodes up and moving only the network gear to the wall would not
  be enough: if the switch lost power, corosync would lose quorum on every node and
  HA would self-fence them, which amounts to a power cut.

So the UPS carries a **dummy load** sized like the real one, and every Ceph node
runs on wall power or stays off. A BMS trip then turns off a heater and nothing
else. Watts are watts to the pack, so runtime at the real load scales from the
dummy-load result (see "Turning the log into thresholds").

NUT still believes it protects the cluster, so it has to be **disarmed for the
window**, not reconfigured. With pve01 on the wall the watchdog would still request
FSD after 60 s on battery, shutting pve01 down for nothing and then cutting the
UPS output. `systemctl stop` is the right tool: it is temporary, needs no PR, and
reverts to armed on the next boot or deploy, which is the safe direction to fail.

### Variants

| | 1a: cluster off (recommended) | 1b: cluster up on wall power | 3: real load, cluster on UPS |
|---|---|---|---|
| Service outage | ~3 to 4 h (one cold cycle) | two short cold cycles, ~20 min each | none |
| Ceph nodes exposed to a BMS trip | no | no | **yes, all three** |
| Exposed to a real grid outage during the window | pve01 only, Ceph already down | **all three, unprotected for ~3 to 4 h** | protected |
| Steps | fewest | twice the plug moves | fewest, but... |
| Verdict | do this | if a long outage is unacceptable | **rejected** for a full discharge |

Variant 3 is only defensible as a short (10 minute) real-load characterisation
with a human acting as the watchdog, and it still carries a small risk of a hard
cut to all three nodes. Not part of this runbook.

The steps below are **1a**. Where 1b differs it says so.

## What you need

- [ ] A **resistive dummy load** of roughly the real cluster wattage (step 0 measures
      it), with **no thermostat cycling**: a space heater on its low setting
      (600 to 750 W) with the thermostat at max, an oil-filled radiator on max, or
      halogen work lights. Not the 1500 W setting: that is ~94% of the UPS rating.
      Keep it on a hard floor, away from cables and the rack.
- [ ] Plug-in **AC watt meter** (Kill A Watt type) that accumulates Wh
- [ ] **DMM** with insulated probes, for per-unit voltages
- [ ] Optional: **DC clamp meter** with inrush or MAX hold, for battery current and
      the transfer surge
- [ ] A **power strip on a wall outlet**, not on the UPS, for pve01 and the network gear
- [ ] A laptop on the LAN with an SSH session to pve01, and the paper field sheet at
      the end of this file

Battery voltage here is 48 to 55 V DC with tens of amps available. Probe one unit
at a time, never bridge terminals, and skip the under-load per-unit readings if the
terminals cannot be reached without moving the pack wiring.

## Picking the date

- [ ] **Not** 2026-10-16 or 2026-10-30 around 18:15: the UPS's 14-day self-test fires
      then (`ups.test.interval` 1209600)
- [ ] Not across midnight or 02:00: the B2 and restic backup jobs run then
- [ ] Daytime, with ~5 hours clear: ~1 h shutdown and setup, up to ~1.5 h discharge,
      ~1 h minimum recharge, ~0.5 h restore and checks
- [ ] Household warned: **DNS is down while the cluster is off**, because dns01 and
      dns02 both live on it. Either accept that or temporarily point the router's DHCP
      DNS at a public resolver first
- [ ] No storms forecast. In 1a a real outage only takes pve01 down; in 1b it hard-cuts
      the whole cluster

## Step 0: Days before (safe, no change to anything)

- [ ] Immich Takeout work finished, no backup running, `ceph -s` HEALTH_OK, no recovery
      or backfill in flight
- [ ] **Measure the real load.** Put the AC meter between the wall and the UPS input
      while on line power and the pack is on float (the charger then draws almost
      nothing). Record meter W and, at the same moment:
      `upsc myups@localhost ups.load`
      Do it once quiet and once with vm-seb (VMID 701) running and busy. The busy
      reading is `P_worst` for the analysis. This also gives a first answer to the W
      vs VA question: `W / (ups.load / 100)` is near 1600 for watts, 2200 for VA.
- [ ] Size the dummy load to the quiet reading, and confirm on the meter that it holds
      steady for 10 minutes without cycling
- [ ] Copy the scripts to pve01 from a checkout of main: `scp scripts/ups-discharge-log.sh scripts/ups-discharge-analyze.py root@pve01:/root/`
- [ ] Check tmux is on pve01: `command -v tmux || apt-get install -y tmux`

## Step 1: Morning of (cluster still running, on the UPS)

- [ ] Pack is full: no on-battery event in the last 24 h. On pve01: `journalctl -u nut-monitor --since "-24h" | grep -i battery`
- [ ] Float reading: `upsc myups@localhost battery.voltage` (expect 55.05)
- [ ] **Per-unit float voltages with the DMM** (units 1 to 4, field sheet). Any unit
      above 13.8 V is imbalance the string total hides (#539)
- [ ] `ceph -s` is HEALTH_OK. jellyfin01's library mount is healthy (a stuck ceph-fuse
      will hang its shutdown, and can hang this check too, hence the timeout): `timeout 15 pct exec 3001 -- mountpoint /mnt/library`
- [ ] Shut down **vm-seb (701) from inside Windows**, not `qm stop`, and any other
      passthrough VM the same way

## Step 2: Stop the cluster

Run on pve01 unless noted.

- [ ] Record which HA resources are running, so step 9 restarts exactly those: `ha-manager status | awk '$1=="service" && /started/ {print $2}' > /root/ha-started-$(date +%F).txt && cat /root/ha-started-$(date +%F).txt`
- [ ] Stop them, so no node tries to fail them over as the others go down: `xargs -a /root/ha-started-$(date +%F).txt -I{} ha-manager set {} --state stopped`
- [ ] Watch until they all read `stopped`: `watch -n5 'ha-manager status'`
- [ ] Stop any non-HA guests still running. Check each node with `qm list; pct list`
- [ ] Ceph flags for a planned full shutdown: `for f in noout norebalance nobackfill norecover; do ceph osd set $f; done`
- [ ] Shut down pve03, then pve02, then pve01: `shutdown -h now`
- [ ] If a node sits at "System is going down" for minutes, it is the `pve-ha-lrm`
      stop-hook hang from the node reboot notes: from a session still on that node,
      `systemctl kill -s SIGKILL pve-ha-lrm`

## Step 3: Re-cable

- [ ] Move **pve01** and the **network gear** to the wall power strip
- [ ] Leave pve02 and pve03 off (their plugs can stay in the UPS)
- [ ] Plug the **dummy load** into a UPS output **through the AC meter** (UPS, meter,
      heater), switched off for now
- [ ] Clamp meter, if used, on one battery string lead, zeroed

**1b:** move pve02 and pve03 to the wall strip too, and boot all three.

## Step 4: Boot pve01 alone, disarm NUT

pve01 boots without quorum. That is expected: NUT works locally, nothing else matters today.

- [ ] Boot pve01 and SSH in
- [ ] NUT armed itself at boot. **Disarm it**, watchdog first because its unit `Wants=` nut-monitor: `systemctl stop nut-onbatt-watchdog && systemctl stop nut-monitor`
- [ ] Verify both are inactive and the driver and upsd are still serving: `systemctl is-active nut-onbatt-watchdog nut-monitor nut-driver@myups nut-server; upsc myups@localhost ups.status`
      Expect `inactive inactive active active` and `OL`
- [ ] No Ansible deploy may run against pve01 during the window: `server.yml` would
      restart both services

**1b:** also run `systemctl stop nut-monitor` on pve02 and pve03. A netclient on its
own shuts its host down on OB+LB, and LB fires at charge < 50.

## Step 5: Start logging, check on line power

- [ ] Start the logger in tmux at 2 s: `tmux new -s ups '/root/ups-discharge-log.sh 2'`
      (detach with `Ctrl-b d`, reattach with `tmux attach -t ups`)
- [ ] Note the CSV path it prints
- [ ] Switch the heater on, still on line power. Watch the meter for 3 minutes: the
      watts must hold steady. Record meter W and the logged `ups.load` (field sheet)
- [ ] For notes during the run (meter readings, DMM readings, anything odd), append
      timestamped lines from a second pane: `echo "$(date +%s) heater 702W 0.12kWh" >> /root/ups-notes.txt`

## Step 6: Pull mains

- [ ] **Unplug the UPS input cord from the wall.** Never use the breaker: in 1b the
      cluster's wall strip may share that circuit
- [ ] Note the time. If the clamp meter has inrush or MAX hold, record the transfer peak
- [ ] The UPS will beep on battery. That is expected

Every 5 minutes, write down AC meter W and Wh, and the clamp reading if used. Every
10 minutes, and every 0.5 V once the string is below 51 V, take per-unit DMM readings
if the terminals are safely reachable.

## Step 7: Stop conditions (any one ends the run)

| Condition | Logger flag | Action |
|---|---|---|
| `battery.voltage` <= 48.0 V | `STOP` | Normal end. Heater off, then step 8 |
| Any single unit <= 11.6 V on the DMM, or units more than 0.5 V apart | none, from the DMM | Weak or unbalanced unit. Heater off, then step 8 |
| String drops >= 1 V in one sample after the first 15 s | `COLLAPSE` | Likely BMS trip. **Restore mains now** |
| `upsc` fails or reports stale data | `NODATA` | UPS output may have died. **Restore mains now** |
| 120 minutes on battery | none | Well past the expected 80. Heater off, then step 8 |
| Heat, smell, swelling, any doubt | none | **Restore mains now** |

`WARN` at <= 49.0 V is the cue to stand by the plug.

**Telling a BMS trip from a UPS cut-off:** after the event, check the string and each
unit with the DMM. A tripped BMS shows one unit near 0 V or the string missing ~13 V.
If the UPS's own firmware cut the output instead, the pack rebounds to around 50 V and
every unit reads roughly the same. A BMS trip ends testing for the day; record it in
#487 and do not repeat the run.

## Step 8: After the stop

- [ ] Heater off. Leave the UPS on battery with no load for **5 minutes** so the pack
      settles (the UPS idles at a few tens of watts, negligible)
- [ ] Rest readings: `upsc myups@localhost battery.voltage` and **per-unit DMM** (field sheet)
- [ ] **Plug the UPS input back in.** Confirm `OL` in the logger
- [ ] Stop the logger (`Ctrl-c` in tmux) and start a slow one for the recharge curve,
      which shows how fast the charger refills the pack: `tmux new -s recharge '/root/ups-discharge-log.sh 30 /root/ups-recharge-$(date +%F).csv'`
- [ ] Copy both CSVs and the notes file off pve01 to the Mac

**Wait at least 60 minutes of charging** before any node goes back on the UPS. At
48 V the pack has only a few minutes left, and the cluster needs ~3 minutes of
battery to shut down cleanly if mains fails during the restore.

## Step 9: Restore the cluster

- [ ] Shut pve01 down: `shutdown -h now`
- [ ] Move pve01 and the network gear back to the UPS. Heater, meter and wall strip out
- [ ] Power on pve01, pve02 and pve03 together
- [ ] Quorum and Ceph: `pvecm status && ceph -s`
- [ ] Clear the flags: `for f in noout norebalance nobackfill norecover; do ceph osd unset $f; done`
- [ ] Restart exactly the HA resources that were running: `xargs -a /root/ha-started-<date>.txt -I{} ha-manager set {} --state started`
- [ ] Start vm-seb and any non-HA guests by hand, and confirm the GPU passthrough
      devices came back (#487 prerequisite)
- [ ] **Confirm NUT re-armed itself at boot.** pve01: `systemctl is-active nut-driver@myups nut-server nut-monitor nut-onbatt-watchdog; upsc myups@localhost battery.charge.low`
      Expect four `active` and `50`. pve02 and pve03: `systemctl is-active nut-monitor`
- [ ] Full check from the Mac, in `ansible/` of a main checkout: `ansible-playbook verify_nut.yml --vault-password-file ~/.ansible/vault-pass-bw.sh`
- [ ] Router DNS back, if it was changed

**1b:** the cluster is already running. Do a second planned cold cycle (step 2) to
move the three nodes back to the UPS, then this step.

## Step 10: Next day, back on float

- [ ] Stop the recharge logger once `battery.voltage` has held at float for an hour
- [ ] **Per-unit DMM** on float again, and **the whole string** with the DMM, compared
      against `upsc myups@localhost battery.voltage`. That settles whether the 55.05 V
      register is accurate or just quantised

## Turning the log into thresholds

Run the analyzer on the Mac against the discharge CSV:

```bash
python3 scripts/ups-discharge-analyze.py ups-discharge-YYYYMMDD-HHMMSS.csv --test-watts <meter W> --worst-watts <P_worst from step 0>
```

It prints the runtime, the energy delivered, whether `ups.load` is W or VA, the
`battery.voltage` step size, a 5-minute table of voltage and charge, when NUT's own
LB (charge < 50) fired and how much time it left, and proposals for both variables.
The numbers are a proposal: read them against the field sheet before believing them.

### `ups_onbatt_shutdown_delay`

```
T_meas    = seconds on battery until 48.0 V (or the stop) at the dummy load P_test
T_worst   = T_meas x P_test / P_worst       energy is fixed, so time scales with load
T_usable  = 0.8 x T_worst                   ageing, temperature, one-sample error
B         = 180 s                           FSD to UPS output off: HOSTSYNC 15 + slowest
                                            node ~54 s + ups.delay.shutdown 20, doubled
ceiling   = T_usable / 2 - B                two back-to-back outages must both fit,
                                            because the timer assumes a full pack
delay     = min(ceiling, 300), whole minutes
```

The 300 s cap is policy, not physics: a few minutes rides through nearly every short
blip, and beyond that the outage is probably long anyway. Raising it later is a
one-line change. If the ceiling comes out **below 60 s**, the pack cannot cover the
shutdown twice: keep 60 and treat it as a capacity problem in #487.

With the expected 60 to 80 minutes, the ceiling lands around 15 to 20 minutes, so
the cap decides and the proposal is 300.

### `ups_charge_low`

This is the backstop for when the watchdog is not running or the pack is not full.
The analyzer finds the point in the run where enough energy was left for two
shutdown budgets at worst-case load, and reads `battery.charge` there.

- **Charge tracks the pack** (it reads 74 or less at that point): propose that value,
  rounded up to an integer, never below the current 50. Above 74 would leave less
  than 10 points of headroom under the lowest on-mains reading of 84 and risks the
  false LB from 2026-10-02.
- **Charge is pinned high until the end:** charge is useless as a threshold. Keep 50
  and add a voltage condition to `ups_is_critical()` in the watchdog instead, at the
  voltage the analyzer prints for that point, applied only while OB. It needs to be
  above the voltage resolution the analyzer reports, or it cannot be trusted.

This also answers the open #487 checkbox on whether `battery.charge` tracks usefully
on battery.

### The PR

Following the repo rules: worktree, feature branch, PR to main, deploy from main only.

- [ ] Worktree from origin/main: `git worktree add .claude/worktrees/nut-thresholds -b nut-measured-thresholds origin/main && git worktree lock .claude/worktrees/nut-thresholds`
- [ ] `roles/nut/defaults/main.yml`: set `ups_onbatt_shutdown_delay` and
      `ups_charge_low`. Replace both **PROVISIONAL** comments with the measurement:
      date, P_test and P_worst, T_meas, Wh delivered, the arithmetic above. Update
      the `ups_poweroff_wait` comment, which says the trigger is a 60 second timer
- [ ] If a voltage condition is needed: new variable (for example
      `ups_critical_voltage`, empty meaning off) templated into `ups_is_critical()`
      in `templates/nut-onbatt-watchdog.sh.j2`, true only while OB
- [ ] `UPS-SHUTDOWN.md`: add a measured-runtime table next to the 2026-09-08 one,
      and correct "Shutdown Timeline" and "Current Behavior Flow" for the new delay
- [ ] `ansible-lint`, push, PR, then `gh pr checks` until green (do not trust
      `gh run watch`)
- [ ] After squash merge, from `ansible/` of a main checkout, check first: `ansible-playbook nut_setup.yml --limit pve01 --check --diff --vault-password-file ~/.ansible/vault-pass-bw.sh`
- [ ] Then apply: `ansible-playbook nut_setup.yml --limit pve01 --vault-password-file ~/.ansible/vault-pass-bw.sh`
      Only pve01 changes: the watchdog and `ups.conf` both live there
- [ ] Verify on pve01: `grep ^THRESHOLD= /usr/local/sbin/nut-onbatt-watchdog; upsc myups@localhost battery.charge.low; systemctl is-active nut-onbatt-watchdog`
- [ ] Post the analyzer output, the field sheet and the CSVs to #487. Update #262 and
      #460. Compare the delivered Wh against the ~920 Wh rating, which settles whether
      the pack has lost capacity since 01/24/25

## Field sheet

```
Date: ____________   Variant: 1a / 1b

STEP 0  real load, on line, float
  quiet:      meter ____ W   ups.load ____ %   -> ____ W/(load/100)
  vm-seb on:  meter ____ W   ups.load ____ %   (P_worst)

STEP 1  per-unit float (V)   U1 ____  U2 ____  U3 ____  U4 ____   string (upsc) ____

STEP 5  heater on line       meter ____ W     ups.load ____ %

STEP 6  mains pulled at ________   transfer peak (clamp) ____ A

  t(min)  meter W  meter Wh  clamp A  string V  U1    U2    U3    U4    notes
  0
  5
  10
  ...

STEP 7  stopped at ________   reason: STOP / unit / COLLAPSE / NODATA / time / other

STEP 8  rest 5 min           U1 ____  U2 ____  U3 ____  U4 ____   string (upsc) ____
        mains restored at ________

STEP 10 per-unit float (V)   U1 ____  U2 ____  U3 ____  U4 ____
        string DMM ____   string upsc ____
```
