# ollama

Publishes the GPU Ollama on ollama01 (LXC 3014 on pve02, RTX 3080 Ti through
Mesa NVK/Vulkan) as the Tailscale Service `svc:ollama`, so Open WebUI on mem01
can use it at `https://ollama.<tailnet>`.

Ollama itself is installed by hand and is not managed here. The role only:

- binds Ollama to `0.0.0.0:11434` with the drop-in `ollama.service.d/listen.conf`
- loads an nftables table, `inet ollama_guard`, that drops port 11434 on every
  interface except `lo`, from its own unit `ollama-firewall.service`
- checks that Ollama answers a request carrying the tailnet Host header

The `tailscale` role publishes the service (`tailscale_serve_services` in
`group_vars/ollama_servers.yml`).

## Why 0.0.0.0 and a firewall

While bound to loopback, Ollama returns 403 for any Host header other than
localhost, a loopback or private IP, or its own hostname. `tailscale serve`
passes the client's Host through to TCP backends (it rewrites it only for Unix
socket backends, which Ollama does not support). Binding to 0.0.0.0 turns the
check off. The firewall keeps that from exposing an API with no auth to VLAN 60.

`listen.conf` sets `Requires=ollama-firewall.service`, so Ollama will not start
without the rule loaded, and stops if the firewall unit is stopped.

## Bootstrap (once, by hand)

ollama01 was not on the tailnet before this role. CI reaches hosts through
Tailscale SSH, so register it first:

1. In the admin console, add `tag:ollama` to `tagOwners`, define the service
   `ollama` (endpoint `tcp:443`), and allow `tag:ci` to SSH to `tag:ollama`. If the grants do not already let
   `tag:mem0` reach Tailscale Services, allow it to reach `svc:ollama` on 443.
2. On ollama01: install Tailscale (`curl -fsSL https://tailscale.com/install.sh | sh`;
   if that leaves a deb822 `tailscale.sources`, delete it, see #610) and run
   `tailscale up --hostname=ollama01 --advertise-tags=tag:ollama --ssh`
   (interactive login; the tag disables key expiry).
3. Deploy: `--tags tailscale,ollama` for ollama01, then `--tags mem0` for mem01.
4. Approve ollama01 for `svc:ollama` in the console if no autoApprover covers it.

## Verify

```
curl -s https://ollama.<tailnet>/api/version      # from a tailnet device
curl -s -m 3 http://<ollama01 LAN IP>:11434/       # from the LAN: must time out
```
