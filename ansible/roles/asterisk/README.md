# asterisk

The kids' home phone (#683). A touchtone phone plugs into a Grandstream HT802
ATA on the LAN, which registers to Asterisk on pbx01 (LXC 3019, VLAN 70,
HA-managed). Parents use softphones that reach pbx01 over Tailscale.

Asterisk itself is built from source by hand, because Debian 13 has no
`asterisk` package. This role manages everything after that:

- `asterisk.service` (upstream's unit with `Type=simple`, since this build has
  no libsystemd to send READY)
- `pjsip.conf`: one endpoint per phone in `asterisk_extensions`, passwords from
  the vault, no anonymous endpoint. The kids' extension only accepts the LAN
  in `permit`
- `extensions.conf`: the dialplan (below)
- `rtp.conf`: audio on UDP 10000-10100 so a Tailscale grant can name it
- `modules.conf`: basic-pbx's explicit module list plus `app_system` (the 911
  alert), `codec_alaw` and `res_clioriginate` (test calls). autoload stays off
- `logger.conf`: errors and warnings to `/var/log/asterisk/messages`
- `pbx-alert` + `/etc/asterisk/apprise.yml`: an Apprise alert, sent as the
  asterisk user, to the same target as the backup and SMART alerts

Phones, speed dials and passwords live in `inventory/group_vars/phone_servers.yml`
and `vault.yml`.

## What the kids' phone can do

| Dial | Result |
|---|---|
| `1`, `2`, `0` | Speed dials (`asterisk_speed_dials`). `0` rings both parents |
| A parent's extension | Rings that parent |
| `911` | Plays "cannot be completed", then sends an Apprise alert. **It does not reach 911.** |
| Anything else | "Your call cannot be completed as dialed" |

Calls *to* the kids' phone do not ring during `asterisk_quiet_hours` (default
20:00-07:00). The caller hears "is unavailable".

The ATA waits for its inter-digit timeout (about 4 s) before sending a single
digit. To make speed dials instant, add `1|2|0` to the start of the HT802's
Dial Plan for port 1, for example `{ 1 | 2 | 0 | x+ | *x+ }`.

## 911

There is no SIP trunk, so 911 cannot work. The dialplan makes sure it never
fails silently: the caller hears a message and the parents get an alert.

The stock prompts say only "I'm sorry, your call cannot be completed as
dialed". A recording that says "use a cell phone to call 911" is better. To use
one, put `no-911.wav` (8 kHz mono, 16-bit) in `/var/lib/asterisk/sounds/en/`
and set `asterisk_no_911_sound: no-911`.

Real 911 needs a SIP trunk with E911 and a registered address (#683, phase 5).
Even then it fails in a power or internet outage, so keep a charged cell phone
nearby: US carriers connect 911 from any working cell phone, plan or not.

## Bootstrap (once, by hand)

pbx01 was created with `pct create` on pve03 from the Debian 13 template:
unprivileged, `nesting=1`, 4 GB on `rbd-ssd`, 512 MB, `vmbr0` with `tag=70`
(untagged on pve03 is VLAN 60, management), DHCP, nameservers 1.1.1.1 8.8.8.8,
then `ha-manager add ct:3019`.

### Build Asterisk

Inside the container, as root. Build with 2 GB of RAM, then drop back to 512 MB
(`pct set 3019 --memory 2048`, build, `pct set 3019 --memory 512`).

```bash
apt-get install -y build-essential pkg-config curl libedit-dev uuid-dev libjansson-dev libxml2-dev libsqlite3-dev libsrtp2-dev libssl-dev
mkdir -p /usr/src/asterisk && cd /usr/src/asterisk
base=https://downloads.asterisk.org/pub/telephony/asterisk
curl -fsSLO $base/asterisk-22-current.tar.gz && curl -fsSLO $base/asterisk-22-current.sha256
echo "$(cut -d' ' -f1 asterisk-22-current.sha256)  asterisk-22-current.tar.gz" | sha256sum -c -
tar xzf asterisk-22-current.tar.gz && cd asterisk-22.*/
./configure --with-pjproject-bundled && make menuselect.makeopts && make -j2
make install && make basic-pbx && make install-logrotate
useradd --system --home /var/lib/asterisk --shell /usr/sbin/nologin asterisk
chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk
sed -i -E 's/^;?runuser *=.*/runuser = asterisk/; s/^;?rungroup *=.*/rungroup = asterisk/' /etc/asterisk/asterisk.conf
```

22 is the LTS branch. `make basic-pbx` lays down a working base config; this
role then replaces `pjsip.conf`, `extensions.conf` and `rtp.conf`.

### Tailscale

1. In the admin console, add `tag:phone` to `tagOwners` and allow `tag:ci` to
   SSH to `tag:phone`. Grant the parents' devices UDP `5060` and
   `10000-10100` to `tag:phone`.
2. On pve03, give the container a TUN device (`/etc/pve/lxc/3019.conf`):
   `lxc.cgroup2.devices.allow: c 10:200 rwm` and
   `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file`, then
   restart it.
3. In the container: install Tailscale (`curl -fsSL https://tailscale.com/install.sh | sh`;
   if that leaves a deb822 `tailscale.sources`, delete it, see #610) and run
   `tailscale up --hostname=pbx01 --advertise-tags=tag:phone --ssh`
   (interactive login; the tag disables key expiry).

### Vault

```yaml
vault_asterisk_sip_passwords:
  "100": "<random, 16+ chars>"
  "101": "<random, 16+ chars>"
  "102": "<random, 16+ chars>"
```

Then deploy `--tags tailscale,asterisk --limit pbx01`.

## Phones

**HT802, port 1** (Port Settings > FXS Port 1): SIP server `pbx01`'s LAN
address, SIP user ID and authenticate ID `100`, the vault password. Port 2 is
spare for a second phone (add extension 103).

**Softphones** (Linphone, Groundwire, Zoiper): domain = pbx01's Tailscale
name, username = the extension, UDP. The phone must be on the tailnet. iOS
suspends SIP apps in the background, so pick one with push notifications and
test that it rings when locked.

## Upgrading Asterisk

There is no package, so a security release means rebuilding: repeat
"Build Asterisk" with the new tarball (the config in `/etc/asterisk` is kept;
skip `make basic-pbx` and the `useradd`), then `systemctl restart asterisk`.
Announcements: https://www.asterisk.org/downloads/security-advisories/

## Verify

```bash
asterisk -rx "pjsip show endpoints"     # 100 Avail once the ATA registers
asterisk -rx "dialplan show from-kids"
pbx-alert "test alert"                  # as root; check it arrives
asterisk -rx "channel originate Local/911@from-kids application Wait 1"   # 911 path, sends a real alert
```

Startup logs "Unable to load config file" for cel, features, acl, udptl and
pjproject. Those are optional files basic-pbx does not ship; Asterisk uses
defaults.

Then from the kids' phone: `1` rings the first parent, `911` plays the message
and sends an alert, `555` is refused.
