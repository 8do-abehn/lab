# Flashing Battery Light on the SU2200

## TL;DR

The **battery charge bar graph** (the column of 5 small LEDs) flashing, with no beeping,
while the UPS is on mains is **cosmetic. Leave it alone.** Decided 2026-11-27.

If it is the single red **Replace Battery** LED instead, or the UPS is beeping, that is a
different problem and this page does not apply.

## Why it flashes

- The pack is LiFePO4 (16S, installed 01/24/25) but the UPS dates from 2000 and models
  runtime for lead acid. Its runtime estimate moves in 60 s steps and is not a measurement
  of anything (see [UPS-SHUTDOWN.md](UPS-SHUTDOWN.md) and [RUNTIME-TEST.md](RUNTIME-TEST.md)).
- The firmware asserts low battery (LB) when its runtime estimate falls to or below its
  threshold, and 120 s is the lowest threshold this unit accepts.
- On 2026-11-27 it read: `ups.status: OL`, `battery.charge: 100`, `battery.voltage: 55.05`,
  `battery.runtime: 120`, `ups.load: 47.3`. Load had grown from about 36% in October, which
  pushed the estimate down to the 120 s floor, so the UPS latched LB on mains and flashes
  the bar graph. No beep because the alarm only sounds on battery.

## Why it is safe to ignore

NUT does not act on the UPS's LB flag. `ups.conf` sets `ignorelb`,
`override.battery.charge.low = 50` and `override.battery.runtime.low = -1`, so shutdown is
decided on charge (and the 60 s on-battery watchdog), not on the fictional runtime. This is
the configuration the NUT `apcsmart` man page recommends for APC units that underestimate
runtime.

Quick check that this is still the situation:

```bash
ssh root@pve01 upsc myups 2>/dev/null | grep -E 'ups.status|battery.charge|battery.runtime|ups.load|ignorelb'
```

Expect `ups.status: OL`, high charge, `battery.runtime` at or near 120, and
`driver.flag.ignorelb: enabled`.

## Ways to make the light stop (researched, not chosen)

| Option | Verdict |
|---|---|
| Lower the load | Probably works: under about 36% load the estimate read 180 to 240 s. Not a fix, just moves off the floor. |
| Reflash the firmware | **Not possible.** Schneider's Firmware Upgrade Wizard excludes all SU, SUA, SUM and SURT prefixes. No public firmware dumps, source or reverse-engineering projects were found. |
| Battery constant (EEPROM register `0`) via programming mode | **Weak evidence, real risk.** Only one secondhand report (a Smart-UPS SC620I, not this model) of it restoring runtime. A wrong programming-mode command (`^Y`) wiped one SU2200's calibration, model and serial data. Neither `apctest` menus nor NUT expose it. |
| `battery.packs` | Not writable on this unit through NUT. |
| `battery.runtime.low` | 120 is already the minimum; raising it makes LB latch earlier. |
| Runtime calibration (`D` / `calibrate.start`) | Needs 100% charge, discharges to about 25%. No evidence it can model a flat LiFePO4 curve; needs the same unprotected window as the runtime test. |
| Replace the UPS | LiFePO4-native units exist (Eaton 5P and 9PX lithium lines). NUT support for specific models was not checked. |

### Battery constant procedure, for reference only

Secondhand, untested on this firmware. Requires stopping the NUT driver (cluster unprotected)
and should only ever happen during a planned window with the cluster on wall power. In
`apctest` terminal mode: `Y` (expect `SM`), `1`, wait about 4 s, `1` (expect `PROG`), `0`
(reads the constant), `+` / `-` to change, `R` to exit. Never send `^Y`, `Z`, `K`, `@`, `S`,
`U`.

## Open question

Whether the firmware itself cuts the load early on battery when its estimate says LB. NUT
settings cannot change that. The 10 s biweekly self-tests have never shown it; the
discharge test in [RUNTIME-TEST.md](RUNTIME-TEST.md) would answer it.

## Sources

- Schneider FAQ FA279197, Firmware Upgrade Wizard supported models:
  <https://se.com/za/en/faqs/FA279197>
- NUT `apcsmart` man page (ignorelb, overrides, instant commands):
  <https://networkupstools.org/docs/man/apcsmart.html>
- NUT APC smart protocol notes (community reverse-engineered):
  <https://networkupstools.org/protocols/apcsmart.html>
- apcupsd `apctest` man page (EEPROM menu, terminal mode warnings):
  <https://manpages.debian.org/experimental/apcupsd/apctest.8.en.html>
- nut-upsuser 2012, battery constant procedure on an SC620I (secondhand):
  <https://lists.alioth.debian.org/pipermail/nut-upsuser/2012-November/008109.html>
- nut-upsuser 2007, SU2200 programming mode and `^Y` damage:
  <https://lists.alioth.debian.org/pipermail/nut-upsuser/2007-January/002155.html>
- Eaton lithium UPS flyer (LiFePO4 chemistry):
  <https://poweradvantage.eaton.com/assets/doc/eaton-lithium-battery-flyer.pdf>
