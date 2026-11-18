# Remote access with Tailscale

Optional, strongly recommended. This document explains why remote access to
Domoticz should be a VPN and not an open port, and how to set up Tailscale on
the Pi Zero 2 W.

---

## Why a VPN and not port forwarding

Domoticz serves **plain HTTP** on port 8080. There is no TLS certificate, and
TLS on a Pi Zero 2 W is expensive to terminate. Consequences of forwarding
8080 on your router:

- Your Domoticz password travels the internet in clear text.
- Every scanner on the internet finds the login page within hours.
- The default `admin/domoticz` credentials are one guess away.
- The Domoticz web UI has a large enough attack surface that it should not be
  exposed to the internet at all.

Tailscale solves exactly this one problem: it builds an encrypted WireGuard
tunnel between your devices, with no inbound port on the router, and
authenticates both ends. You keep plain HTTP inside the tunnel, which is fine —
the tunnel provides confidentiality, integrity, and identity.

### Threat model

| Threat | Without VPN (port forward) | With Tailscale |
| --- | --- | --- |
| Internet-wide scanning and brute force | Exposed, constant | No listener on the internet |
| Credential sniffing on the path | Plain HTTP | WireGuard encryption |
| Unauthorized device reaching the UI | Anyone who finds the port | Only nodes in your tailnet, filtered by ACLs |
| Stolen laptop/phone | Full access | Node can be revoked centrally |
| Malicious LAN client | Full access | Unaffected by Tailscale; still needs your LAN firewall |

Rules that follow from this:

- Tailscale **does not** justify weak credentials. Change `admin/domoticz` and
  keep MQTT authentication enabled.
- Never enable **Tailscale Funnel**. It publishes a node to the public
  internet — the exact thing this document avoids.
- Do not advertise the Pi as an exit node; it has no capacity for it.
- The VPN protects the transport, not the application. Keep the LAN firewall
  rules from the README.

---

## 1. Install

Tailscale provides per-codename Debian repositories. On Raspberry Pi OS
Trixie:

```bash
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/trixie.noarmor.gpg \
  | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/trixie.tailscale-keyring.list \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt-get update
sudo apt-get install -y tailscale
```

On Bookworm, replace `trixie` with `bookworm` in both URLs. Pin the package
version if you want reproducible rebuilds (`apt-cache policy tailscale`, then
`apt-get install tailscale=<version>`).

Check the daemon:

```bash
systemctl status tailscaled --no-pager
```

## 2. Join the tailnet with a tagged auth key

Create an auth key in the Tailscale admin console (*Settings → Keys*), ideally
an ephemeral-free, pre-authorized key tagged `tag:domoticz`. Then:

```bash
sudo tailscale up --auth-key=<AUTH_KEY> --advertise-tags=tag:domoticz
```

Do not use `--ssh` unless you specifically want Tailscale SSH; the normal SSH
service is enough.

Verify:

```bash
tailscale status
tailscale ip -4
```

## 3. Restrict access with ACLs

An ACL that lets your own devices reach only the Domoticz UI:

```json
{
  "tagOwners": {
    "tag:domoticz": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:domoticz:8080"]
    }
  ]
}
```

Add `"tag:domoticz:1883"` only if a Zigbee2MQTT instance runs on another host
and must reach the broker over the tailnet. Do not grant general access: list
exact ports.

## 4. Use it

With MagicDNS enabled, the Pi is reachable at its tailnet name:

```
http://domoticz.<YOUR_TAILNET>.ts.net:8080
```

Test from a phone on mobile data with Tailscale connected — not on the home
Wi-Fi, which would hide a broken tunnel. Test from a machine that is **not** in
the tailnet and confirm it gets nothing.

### Firewall interaction

Domoticz binds `0.0.0.0:8080`, but your firewall still applies. If you added a
LAN-only rule for 8080, tailnet traffic arrives on `tailscale0` with a `100.x`
source address and will be dropped. Add:

```bash
sudo ufw allow in on tailscale0 to any port 8080 proto tcp
```

Confirm the default policy still denies everything else:

```bash
sudo ufw status verbose
```

## 5. Resource footprint on the Pi Zero 2 W

```bash
ps -o rss=,vsz= -C tailscaled
free -m
```

Expect roughly 30–60 MB RSS. That is real memory on a 512 MB board, so measure
it together with Domoticz and Zigbee2MQTT before you rely on the numbers here.
When remote access is not needed for a while:

```bash
sudo tailscale down
```

`tailscaled` stays running and reconnects on `tailscale up`.

## 6. Revocation and rotation

- **Lost device:** admin console → *Machines* → remove the node. Access stops
  immediately; no change on the Pi is needed.
- **Node compromise:** revoke the Pi's node and re-authenticate it with a new
  auth key.
- **Leaving the tailnet:** `sudo tailscale logout` on the Pi.
- Use key expiry (default on) for personal devices; disable it only for
  headless nodes that cannot re-authenticate, and compensate with tags and
  ACLs.

## 7. Uninstall

```bash
sudo tailscale down
sudo systemctl disable --now tailscaled
sudo apt-get remove --purge tailscale
sudo rm -f /etc/apt/sources.list.d/tailscale.list \
  /usr/share/keyrings/tailscale-archive-keyring.gpg
```

Then remove the node in the admin console.

---

## What this does not cover

- **TLS on Domoticz itself.** Not needed inside the tunnel; out of scope for
  the LAN too (see `PLAN.md`, P1.7).
- **MQTT exposure.** The broker stays localhost-only unless `--mqtt-lan` is
  used. Tailscale is not a reason to publish 1883 to the internet.
- **LAN segmentation.** A guest on your Wi-Fi can still reach 8080 unless your
  firewall restricts it.
