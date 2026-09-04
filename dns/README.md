# DNS as code (octoDNS)

Manages DNS for `abehn.com`, `b3hn.com`, and `behn.email` via Cloudflare.

These zones live in a **different Cloudflare account** than the lab zone
(`8devops.com`). Different nameserver pairs confirm it: the lab is on
`carlos/margaret.ns.cloudflare.com`, these are on `amit/lily.ns.cloudflare.com`.
The tunnel token in `ansible/vault.yml` will not work here, and should not be
reused for DNS regardless since it carries Workers and Access scopes.

## One time setup

### 1. Create a scoped API token

In the Cloudflare dashboard for the account holding these zones:

My Profile > API Tokens > Create Token > Create Custom Token

- **Permissions:** `Zone` > `DNS` > `Edit`
- **Zone Resources:** Include > Specific zone, once for each of the three
  domains. Avoid "All zones" so the token cannot touch anything else.
- **TTL:** set an expiry and calendar a rotation.

`DNS:Edit` implies read, so one token covers both `plan` and `apply`.

### 2. Store the token outside the repo

Create the file yourself and paste the token in. Do not pass it on a command
line, where it would land in shell history.

    mkdir -p ~/.config/octodns
    vi ~/.config/octodns/cloudflare-token
    chmod 600 ~/.config/octodns/cloudflare-token

`dns.sh` refuses to run if that file is not mode 600.

Override the location with `CLOUDFLARE_TOKEN_FILE` if you keep secrets
elsewhere.

### 3. Install octoDNS

    pipx install octodns && pipx inject octodns octodns-cloudflare

## Usage

    ./dns.sh dump     # pull live zones into ./zones, first run only
    ./dns.sh plan     # show the diff, read only
    ./dns.sh apply    # push changes

`plan` is the default posture: `octodns-sync` does nothing without `--doit`.
Always read a `plan` before an `apply`, the same way you would `--check --diff`
an Ansible play.

## Important: octoDNS prunes

octoDNS reconciles the **whole zone**. Any record present in Cloudflare but
absent from `./zones` will be **deleted** on apply. That is the point, it is
how residue gets found and removed, but it means `dump` must run before the
first `apply` or you will wipe records you meant to keep.

Read every deletion in a `plan` before applying it.

## Related

Audit and rationale for these records: issue #447, which covers the
SPF/DKIM/DMARC/BIMI review these zone files implement.
