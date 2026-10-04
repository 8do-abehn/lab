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
| Input plug | **NEMA 5-15P**, swapped by a previous owner (the US SU2200 normally ships with an L5-30P twist-lock). See the note below |

**The 15 A input plug caps this UPS well below its rating.** At 2200 VA it would draw
over 18 A, which a 5-15 plug and outlet are not built for. Keep everything the UPS
powers, including its charger, under about **1440 W** (80% of 15 A, the continuous
limit for the plug, the outlet and a 15 A breaker). Today's ~600 to 800 W is fine.
For this test, never have the cluster and the heater on the UPS at the same time,
and put the cluster's wall strip on a **different circuit** from the UPS: during
step 5 the heater and the charger run from mains through the UPS, and the cluster on
the same 15 A circuit would bring the total near 1500 W. Check the input plug and
the wall outlet for warmth by hand during step 5.

Expected if healthy (arithmetic, not measured): ~36% load is ~580 W out, ~650 to
730 W from the battery, ~12 to 15 A, roughly **60 to 80 minutes** to 48 V (a little less to the 49 V stop used here). If
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

| | 1a: cluster off | **1b: cluster up on wall power (chosen)** | 3: real load, cluster on UPS |
|---|---|---|---|
| Service outage | ~3 to 4 h (one cold cycle) | two short cold cycles, ~20 to 30 min each | none |
| Ceph nodes exposed to a BMS trip | no | no | **yes, all three** |
| Exposed to a real grid outage during the window | pve01 only, Ceph already down | **all three, unprotected for ~3 h** | protected |
| Steps | fewest | twice the plug moves | fewest, but... |
| Verdict | | **chosen 2026-10-03**: services stay up | **rejected** for a full discharge |

Variant 3 is only defensible as a short (10 minute) real-load characterisation
with a human acting as the watchdog, and it still carries a small risk of a hard
cut to all three nodes. Not part of this runbook.

The steps below are **1b**. For 1a instead: in step 3 move only pve01 and the
network gear, leave pve02 and pve03 off, boot pve01 alone in step 4 (no quorum is
expected), skip restoring services, and fold the second cold cycle into a single
boot at step 9.

A rolling re-plug (drain one node at a time) would avoid both outages, but the
network gear cannot move while the cluster runs: the switch rebooting takes corosync
quorum away from every node long enough for HA to self-fence them.

## What you need

- [ ] A **resistive dummy load** of roughly the real cluster wattage (step 0 measures
      it), with **no thermostat cycling**: a space heater on its low setting
      (600 to 750 W) with the thermostat at max, an oil-filled radiator on max, or
      halogen work lights. Not the 1500 W setting: that is ~94% of the UPS rating.
      Keep it on a hard floor, away from cables and the rack.
- [ ] **Kasa KP115** energy-monitoring plug (on hand) between the UPS and the heater.
      The logger polls it over the LAN every sample, so watts and Wh land in the
      same CSV row as the battery voltage and nobody reads a meter by eye. Give it a
      DHCP reservation so its address cannot change mid-test, and keep it on the
      main LAN: pve01 reaches it there on TCP 9999 with no TP-Link login. It sits
      near the edge of Wi-Fi range where it was first tested (RSSI -76), so check the
      signal at the UPS; a dropped reading only leaves two empty cells
- [ ] A **power strip on a wall outlet**, not on the UPS, for pve01 and the network gear
- [ ] A laptop on the LAN with an SSH session to pve01, and the paper field sheet at
      the end of this file

No multimeter or clamp readings. The battery terminals are not reachable inside the
case, so this test sees the pack only through the UPS's `battery.voltage` register
and the KP115's output watts. Two consequences, both accepted:

- **The register itself is unverified**, and the hard stop depends on it.
- **A single weak unit cannot be seen**: the string total can look fine while one
  of the four units is much lower than the rest.

Both are covered by stopping at **49.0 V instead of 48.0 V** (about 3.06 V per cell
instead of 3.0). That absorbs a register error of up to about a volt and leaves a
weaker unit room before its BMS cuts out. The cost is the last few percent of
capacity, which the threshold arithmetic already discards through its 0.8 derate.
Battery current, if wanted, follows from `watts / battery.voltage / ~0.85`.

If the battery tray is ever out for another reason, see "Readings if the tray is
out" near the end.

## Picking the date

- [ ] **Not** 2026-10-16 or 2026-10-30 around 18:15: the UPS's 14-day self-test fires
      then (`ups.test.interval` 1209600)
- [ ] Not across midnight or 02:00: the B2 and restic backup jobs run then
- [ ] Daytime, with ~5 hours clear: ~0.5 h cold cycle 1, ~0.5 h setup, up to ~1.5 h
      discharge, ~1 h minimum recharge, ~0.5 h cold cycle 2 and checks
- [ ] Household warned about **two outages of ~20 to 30 minutes** (steps 2 to 4 and
      step 9). DNS goes with them, because dns01 and dns02 both live on the cluster
- [ ] No storms forecast. Between the cold cycles the cluster runs on wall power with
      no UPS, so a real outage hard-cuts all three Ceph nodes

## Step 0: Days before (safe, no change to anything)

- [ ] Immich Takeout work finished, no backup running, `ceph -s` HEALTH_OK, no recovery
      or backfill in flight
- [ ] **Measure the real load in watts with the KP115 on the UPS input** (wall, KP115,
      UPS). The input is a 5-15P, so the plug fits, and at ~6 A it is well inside
      the KP115's 15 A rating. Read it once quiet and once with vm-seb (VMID 701)
      running and busy, along with `upsc myups@localhost ups.load` at the same moment:
      `python3 scripts/kp115-read.py <plug address>`
      The busy watts are the worst case for the analysis (`--worst-watts`). The input
      reading includes the UPS's own losses and a float-level charger, so it reads a
      little high, which errs safe.
      **Stay with it and keep it short (minutes, not days).** The cluster is now
      powered through a Wi-Fi relay: if the KP115 switches off from the app, a
      schedule or a firmware update, the cluster goes on battery, and after 60 s the
      watchdog shuts all three nodes down. Turn off the plug's auto-update and remove
      any schedules first, and move it out of the input path when done
- [ ] Size the dummy load to roughly the quiet reading (36% is about 580 W if
      `ups.load` is watts), and confirm on the KP115 that it holds steady for 10
      minutes without cycling: `python3 scripts/kp115-read.py <plug address>`
- [ ] **Find a second circuit** for the cluster's wall strip: a different breaker from
      the outlet the UPS is plugged into. Confirm by switching that breaker off with
      nothing important on it, or with a plug-in tester. It has to carry the three
      nodes and the network gear, ~600 to 800 W
- [ ] Copy the scripts to pve01 from a checkout of main: `scp scripts/ups-discharge-log.sh scripts/ups-discharge-analyze.py scripts/kp115-read.py root@pve01:/root/`
- [ ] Check tmux is on pve01: `command -v tmux || apt-get install -y tmux`

## Step 1: Morning of (cluster still running, on the UPS)

- [ ] Pack is full: no on-battery event in the last 24 h. On pve01: `journalctl -u nut-monitor --since "-24h" | grep -i battery`
- [ ] Float reading: `upsc myups@localhost battery.voltage` (expect 55.05)
- [ ] `ceph -s` is HEALTH_OK. jellyfin01's library mount is healthy (a stuck ceph-fuse
      will hang its shutdown, and can hang this check too, hence the timeout): `timeout 15 pct exec 3001 -- mountpoint /mnt/library`
- [ ] Shut down **vm-seb (701) from inside Windows**, not `qm stop`, and any other
      passthrough VM the same way

## Step 2: Cold cycle 1, stop the cluster

Run on pve01 unless noted. Step 9 repeats this exact procedure.

- [ ] Record which HA resources are running, so they can be restarted exactly: `ha-manager status | awk '$1=="service" && /started/ {print $2}' > /root/ha-started-$(date +%F).txt && cat /root/ha-started-$(date +%F).txt`
- [ ] Stop them, so no node tries to fail them over as the others go down: `xargs -a /root/ha-started-$(date +%F).txt -I{} ha-manager set {} --state stopped`
- [ ] Watch until they all read `stopped`: `watch -n5 'ha-manager status'`
- [ ] Stop any non-HA guests still running. Check each node with `qm list; pct list`
- [ ] Ceph flags for a planned full shutdown: `for f in noout norebalance nobackfill norecover; do ceph osd set $f; done`
- [ ] Shut down pve03, then pve02, then pve01: `shutdown -h now`
- [ ] If a node sits at "System is going down" for minutes, it is the `pve-ha-lrm`
      stop-hook hang from the node reboot notes: from a session still on that node,
      `systemctl kill -s SIGKILL pve-ha-lrm`

## Step 3: Re-cable onto wall power

- [ ] Move **pve01, pve02, pve03 and the network gear** to the wall power strip, on
      the **other circuit** found in step 0
- [ ] The network gear is not optional here. Left on the UPS, a BMS trip would drop
      the switch, corosync would lose quorum on every node, and HA would self-fence
      all three: a power cut by another name
- [ ] Plug the **dummy load** into a UPS output **through the KP115** (UPS, KP115,
      heater), heater switched off for now, KP115 switched on

## Step 4: Boot the cluster on wall power, disarm NUT, restore services

- [ ] Power on the network gear, wait for it to come up, then power on pve01, pve02
      and pve03 together
- [ ] Quorum and Ceph: `pvecm status && ceph -s` (HEALTH_WARN for the flags is expected)
- [ ] NUT armed itself at boot on all three. **Disarm it before anything else.** On
      pve01, watchdog first because its unit `Wants=` nut-monitor: `systemctl stop nut-onbatt-watchdog && systemctl stop nut-monitor`
- [ ] On pve02 and pve03: `systemctl stop nut-monitor`. A netclient on its own shuts
      its host down on OB+LB, and LB fires at charge < 50
- [ ] Verify on pve01, expecting `inactive inactive active active` and `OL`: `systemctl is-active nut-onbatt-watchdog nut-monitor nut-driver@myups nut-server; upsc myups@localhost ups.status`
- [ ] Verify on pve02 and pve03, expecting `inactive`: `systemctl is-active nut-monitor`
- [ ] Clear the flags: `for f in noout norebalance nobackfill norecover; do ceph osd unset $f; done`
- [ ] Restart the HA resources that were running: `xargs -a /root/ha-started-$(date +%F).txt -I{} ha-manager set {} --state started`
- [ ] Start non-HA guests as wanted. Services are back; the outage is over until step 9
- [ ] No Ansible deploy may run against any node during the window: `server.yml` and
      `client.yml` would restart the NUT services

**From here until step 9 the cluster has no UPS protection.** A real grid outage
hard-cuts all three Ceph nodes. That is the accepted cost of 1b, so keep the window
moving: the discharge, the recharge wait and step 9 should follow each other without
gaps.

## Step 5: Start logging, check on line power

- [ ] Start the logger in tmux at 2 s, polling the KP115: `tmux new -s ups 'KP115_HOST=<plug address> /root/ups-discharge-log.sh 2'`
      (detach with `Ctrl-b d`, reattach with `tmux attach -t ups`)
- [ ] Note the CSV path it prints
- [ ] Switch the heater on, still on line power. Watch `plugW` for 3 minutes: it must
      hold steady. Record it and the logged `ups.load` (field sheet). This is the
      calibration: `plugW / (ups.load / 100)` near 1600 means `ups.load` is watts,
      near 2200 means VA
- [ ] Feel the UPS input plug and its wall outlet: warm is a reason to stop here
- [ ] **Do not use the Kasa app to switch the KP115 during the run.** Switching it off
      ends the test early; the heater's own switch is the load control
- [ ] For notes during the run (anything odd: a sound, a smell, the KP115 dropping
      off Wi-Fi), append timestamped lines from a second pane: `echo "$(date +%s) plug offline, app shows 702W" >> /root/ups-notes.txt`

## Step 6: Pull mains

- [ ] **Unplug the UPS input cord from the wall.** Never use a breaker: that is how
      the cluster's circuit gets switched off by mistake
- [ ] Note the time
- [ ] The UPS will beep on battery. That is expected

The logger records voltage, charge, watts and Wh. Glance at `plugW` now and then: if
it reads blank for more than a minute, note the watts from the Kasa app instead.

## Step 7: Stop conditions (any one ends the run)

| Condition | Logger flag | Action |
|---|---|---|
| `battery.voltage` <= 49.0 V | `STOP` | Normal end. Heater off, then step 8 |
| String drops >= 1 V in one sample after the first 15 s | `COLLAPSE` | Likely BMS trip. **Restore mains now** |
| `upsc` fails or reports stale data | `NODATA` | UPS output may have died. **Restore mains now** |
| 120 minutes on battery | none | Well past the expected 80. Heater off, then step 8 |
| Heat, smell, swelling, any doubt | none | **Restore mains now** |

`WARN` at <= 50.0 V is the cue to stand by the plug.

**Telling a BMS trip from a UPS cut-off:** restore mains and read
`upsc myups@localhost battery.voltage` once the driver is back. If the UPS's own
firmware cut the output, the pack rebounds to around 50 V or more. If a unit's BMS
tripped, the string is open or one unit short: expect a reading near 0, roughly 13 V
low (around 38 V), or the UPS reporting a battery fault. A BMS trip ends testing for
the day; record it in #487 and do not repeat the run. A tripped unit may not wake from
the UPS's charger, and could need a 12 V LiFePO4 charger on that unit alone, which
means opening the case.

## Step 8: After the stop

- [ ] Heater off. Leave the UPS on battery with no load for **5 minutes** so the pack
      settles (the UPS idles at a few tens of watts, negligible)
- [ ] Rest reading: `upsc myups@localhost battery.voltage` (field sheet). LiFePO4 rests
      around 50 to 51 V when nearly empty; much lower suggests a weak unit
- [ ] **Plug the UPS input back in.** Confirm `OL` in the logger
- [ ] Stop the logger (`Ctrl-c` in tmux) and start a slow one for the recharge curve,
      which shows how fast the charger refills the pack: `tmux new -s recharge '/root/ups-discharge-log.sh 30 /root/ups-recharge-$(date +%F).csv'`
- [ ] Copy both CSVs and the notes file off pve01 to the Mac

**Wait at least 60 minutes of charging** before any node goes back on the UPS. At
49 V the pack has only a few minutes left, and the cluster needs ~3 minutes of
battery to shut down cleanly if mains fails during the restore.

## Step 9: Cold cycle 2, back onto the UPS

After at least 60 minutes of charging (step 8).

- [ ] **Re-arm check comes last, not first:** NUT stays disarmed while the nodes are on
      wall power, because an armed watchdog on pve01 would still act on the UPS
- [ ] Repeat **step 2** exactly, including recording the HA resources again (services
      may have moved since the morning, and the file is simply overwritten)
- [ ] With everything off, move **pve01, pve02, pve03 and the network gear** back to
      the UPS. Heater, KP115 and wall strip out
- [ ] Power on the network gear, wait for it, then pve01, pve02 and pve03 together
- [ ] Quorum and Ceph: `pvecm status && ceph -s`
- [ ] Clear the flags: `for f in noout norebalance nobackfill norecover; do ceph osd unset $f; done`
- [ ] Restart the HA resources: `xargs -a /root/ha-started-$(date +%F).txt -I{} ha-manager set {} --state started`
- [ ] Start vm-seb and any non-HA guests by hand, and confirm the GPU passthrough
      devices came back (#487 prerequisite)
- [ ] **Confirm NUT re-armed itself at boot.** pve01: `systemctl is-active nut-driver@myups nut-server nut-monitor nut-onbatt-watchdog; upsc myups@localhost battery.charge.low`
      Expect four `active` and `50`. pve02 and pve03: `systemctl is-active nut-monitor`
- [ ] Full check from the Mac, in `ansible/` of a main checkout: `ansible-playbook verify_nut.yml --vault-password-file ~/.ansible/vault-pass-bw.sh`

## Step 10: Next day, back on float

- [ ] Stop the recharge logger once `battery.voltage` has held at float for an hour
- [ ] Note `upsc myups@localhost battery.voltage` back on float. If it returns to
      exactly 55.05, that is more evidence the register is coarse

## Turning the log into thresholds

Run the analyzer on the Mac against the discharge CSV:

```bash
python3 scripts/ups-discharge-analyze.py ups-discharge-YYYYMMDD-HHMMSS.csv --worst-watts <busy KP115 watts from step 0>
```

The test wattage comes from the KP115 readings in the log. If they are missing,
pass `--test-watts` with the value from the Kasa app. It prints the runtime, the
energy delivered (also from the KP115's own Wh counter), whether `ups.load` is W or VA, the
`battery.voltage` step size, a 5-minute table of voltage and charge, when NUT's own
LB (charge < 50) fired and how much time it left, and proposals for both variables.
The numbers are a proposal: read them against the field sheet before believing them.

### `ups_onbatt_shutdown_delay`

```
T_meas    = seconds on battery until the 49.0 V stop at the dummy load P_test
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

## Readings if the tray is out

Not part of this test. If the battery tray is ever out for another reason, with the
UPS off and unplugged, take these and add them to #487, which closes the open
imbalance check from #539:

- Each unit with a multimeter, labelled 1 to 4. Any unit above 13.8 V, or units more
  than 0.1 V apart, is imbalance the string total hides
- The whole string, and right after reinserting the tray and powering up, compare it
  with `upsc myups@localhost battery.voltage`. More than 0.3 V apart means the
  register is off, and the next discharge's stop should move by the difference

Battery voltage is 48 to 55 V DC with tens of amps available. Probe one unit at a
time and never bridge terminals.

## Field sheet

```
Date: ____________   Variant: 1b

STEP 0  real load, on line, float
  quiet:      KP115 on UPS input ____ W   ups.load ____ %
  vm-seb on:  KP115 on UPS input ____ W   ups.load ____ %   (worst case)

STEP 1  float string (upsc) ____

STEP 5  heater on line       KP115 ____ W     ups.load ____ %   -> ____ W/(load/100)

STEP 4  services back at ________  (outage 1: ____ min)

STEP 6  mains pulled at ________

  voltage, charge, watts and Wh are all in the CSV

STEP 7  stopped at ________   reason: STOP / COLLAPSE / NODATA / time / other

STEP 8  rest 5 min           string (upsc) ____
        mains restored at ________

STEP 9  services back at ________  (outage 2: ____ min)   NUT re-armed: yes / no

STEP 10 back on float        string (upsc) ____
```
