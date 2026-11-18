# Development Roadmap

Status as of 2026-11-18:

- `v1.0.0` is the frozen Raspberry Pi Zero W (ARMv6) reference.
- The current line targets the Raspberry Pi Zero 2 W only: `v2.0.0` is merged
  to `main` and published as a pre-release. It awaits a hardware test before
  being promoted to a full release.
- `v2.1.0-rc2` is published as a pre-release from `release/v2.1.0` (MQTT
  authentication, Zigbee2MQTT guide, Tailscale). It supersedes `rc1` and awaits
  the hardware test list in `README.md`.

**Next action:** `v2.1.0-rc2` is prepared and its download links are live in the
README. Development is **paused** until the Pi Zero 2 W and the MG24 dongle
arrive; then run the `PENDING HARDWARE TEST` list from the README, update the
rows, the `CHANGELOG` pending list, and tag `v2.1.0`.

## Context for the next session

- Target: Raspberry Pi Zero 2 W, 64-bit Raspberry Pi OS Lite (aarch64, Debian
  12 or newer; Trixie is current), with SSH access and a `sudo` user.
- The script performs eight steps plus one optional step: preflight validation ->
  system update and dependencies -> download and verify the pinned release ->
  service account and directories -> install files -> systemd unit -> Mosquitto
  -> optional Tailscale (`--tailscale`) -> verify.
- Pinned artifacts live at the top of `setup_domoticz.sh`. To bump Domoticz,
  update the version, URL, and SHA256 together:

  ```bash
  curl -sSL -o /tmp/domoticz.tgz "$DOMOTICZ_TARBALL_URL"
  curl -sSL -o /tmp/domoticz.tgz.sha256sum \
    "https://github.com/domoticz/domoticz/releases/download/<version>/domoticz_linux_aarch64.tgz.sha256sum"
  sha256sum /tmp/domoticz.tgz
  cat /tmp/domoticz.tgz.sha256sum
  ```

- `v1.0.0` is frozen: do not add ARMv6 support back, and do not maintain
  `maint/1.x`.
- Layout: application files are root-owned in `/opt/domoticz`; the database,
  plugins, scripts, and backups are in `/var/lib/domoticz`; logs go to the
  journal.
- The internal Domoticz updater is disabled with `-noupdates`; upgrades happen
  only by bumping the pinned release.
- Do NOT: host Domoticz binaries in releases (GPLv3 source obligation), use
  mutable URLs, or reintroduce CRLF line endings.
- `git log` is the source of truth for status; the Done list below is a snapshot.
- Hardware for the device integrations: a SONOFF Zigbee/Thread USB Dongle Plus
  MG24 on the Pi Zero 2 W (Zigbee coordinator mode only, firmware 8.0.2, adapter
  `ember`), with Zigbee2MQTT as the bridge and Mosquitto as the transport. Goal
  is local Tuya control with the cloud blocked; no other integration path is
  planned. Decisions and remaining unknowns: see "Open questions".
- Zigbee2MQTT runs as a Podman container from the pinned official image; the
  Domoticz + Mosquitto install stays native until `v3.0.0`.
- Container mode (P4) is the `v3.0.0` target, not part of the native install
  flow; keeping the two apart is deliberate.
- Maintenance procedure: `.opencode/skills/domoticz-zero2w/SKILL.md`; keep it in
  sync with this plan.
- Deployment guides live in `docs/`. They are written first, then verified on
  hardware; when a guide and the script disagree, the script wins and the guide
  is a bug.
- Current work happens on `release/v2.1.0`; `main` keeps the `v2.0.0` line until
  the RC passes the hardware test and is merged. `CHANGELOG.md` records every
  released tag, including release candidates.

## Done

- [x] Squashed history into an `Initial commit` plus a dedicated hardening commit
- [x] README cleanup (removed draft artifact) and correct file permissions
- [x] Line endings normalized to LF + `.gitattributes` (CRLF previously broke the `#!` line)
- [x] **P0.1** `set -euo pipefail` + `trap ... ERR` reporting the failing line
- [x] **P0.2** Idempotent adding/commenting of the Buster repository (obsolete in v2)
- [x] **P0.3** Pinned artifacts + SHA256 verification
- [x] **P0.4** Validation of architecture, required commands, and free space
- [x] **P0.5** `DEBIAN_FRONTEND=noninteractive`
- [x] **P1.6** Safe service-user detection (v2 uses a dedicated `domoticz` system user)
- [x] **P2.10** ShellCheck CI (`.github/workflows/shellcheck.yml`); also runs on
      `release/**` pushes so release candidates are linted without a manual
      dispatch
- [x] **P2.11 (v1.0.0)** Tag and GitHub release for the Pi Zero W reference
- [x] **v2.0.0 port** Domoticz 2026.4 aarch64, platform validation, no ARMv6
      workarounds, pinned artifact and checksum
- [x] **P1.8 (layout)** `/opt/domoticz`, `/var/lib/domoticz`, dedicated system
      user, hardened unit, journal logging
- [x] **P1.7 / v2.1.0** Mandatory MQTT authentication, `--mqtt-lan`, `--help`,
      credential hashing and self-verification
- [x] **P1.10 / v2.1.0** Optional `--tailscale` step and `docs/tailscale.md`
- [x] **P3 docs / v2.1.0** `docs/zigbee2mqtt.md` (MG24, firmware 8.0.2, `ember`,
      container unit, MQTT Auto Discovery, pairing, backups, Device Support table)
- [x] **P2.11 / v2.1.0-rc2** `release/v2.1.0`, `CHANGELOG.md`, README "Tested on",
      rc1 and rc2 published as pre-releases
- [x] `main` and `release/v2.1.0` pushed; CI lints both (`release/**`)
- [x] README: current board/OS, install from the release asset, layout, backup,
      database migration, firewall hint, uninstall

## P1 — Reliability and security

### 7. Mosquitto configuration

The broker is installed, enabled, and now requires authentication:

- [x] `/etc/mosquitto/conf.d/domoticz.conf`: `allow_anonymous false`, `password_file /etc/mosquitto/passwd`
- [x] Add `--mqtt-lan` and `--help` flags to the installer
- [x] Create the `domoticz` MQTT user with a generated password (`openssl rand -hex 16`), printed once; skip creation if the password file already exists
- [x] Require `openssl` (already used for the version check) plus `mosquitto_passwd`, `mosquitto_pub`, and `ss`
- [x] `listener 1883 0.0.0.0` only behind `--mqtt-lan`
- [x] Restart Mosquitto after writing the config and verify auth: anonymous publish rejected, authenticated publish accepted
- [x] README: how to add the broker as a "hardware" entry in Domoticz and how to add more devices
- [x] README: clear warning that enabling auth requires configuring credentials in Domoticz/ESP, otherwise things stop working
- [ ] Test on a real Zero 2 W: `--help`, unknown flag (exit 2), fresh install,
      re-run (credentials unchanged), `--mqtt-lan` add/remove, password reset

Passwords are hashed with `mosquitto_passwd -U` from a `0600` temporary file so
the plain text never appears in a process argument.

Out of scope: TLS — its performance cost on a Pi Zero 2 W is still
disproportionate for a home LAN.

Implementation contract:

- CLI: `--mqtt-lan` and `--help`; an unknown flag exits with code 2 and prints
  usage.
- Declarative state: `listener 1883 0.0.0.0` is present **if and only if**
  `--mqtt-lan` was passed. Re-running without the flag removes it.
- Credentials: create the password file only when it does not exist. When it
  exists, print "existing credentials unchanged" and do not touch it.
- File mode `0600`, owner `mosquitto:mosquitto`; restart Mosquitto after writing
  the configuration.
- The script verifies the result itself:
  - `mosquitto_pub` without credentials fails;
  - `mosquitto_pub` with the generated credentials succeeds;
  - `ss -ltn` shows `127.0.0.1:1883` without the flag and `0.0.0.0:1883` with it.

### 8. Layout and service hardening

Shipped in `v2.0.0`; recorded here because the layout is part of the public API.

- [x] Application files root-owned and read-only to the service in `/opt/domoticz`
- [x] Database, plugins, scripts, and backups in `/var/lib/domoticz` (`0750`)
- [x] Dedicated `domoticz` system user with `nologin` and a matching group
- [x] Hardened unit: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`,
      `ProtectHome`, `ProtectControlGroups`, `RestrictSUIDSGID`, `UMask=0027`,
      `ReadWritePaths`, `StateDirectory`
- [x] Logs go to the systemd journal; no file-based logrotate rule
- [x] No automatic migration from the old `$HOME` layout; moving
      `domoticz.db` stays a documented manual step

### 9. Network exposure and default credentials

- [x] README: port 8080 listens on `0.0.0.0`; show `ufw allow from <LAN> to any port 8080`
- [x] README: stronger warning about `admin/domoticz`
- [x] With `--mqtt-lan`, print the `ufw` rule for port 1883 and warn if the firewall is inactive (never install `ufw` silently)

### 10. Remote access with Tailscale

Remote access is a VPN, never an open port. Domoticz keeps listening on the LAN;
Tailscale grants access to trusted devices only.

- [x] `--tailscale` flag: add the official repository for the detected codename,
      install the package, enable `tailscaled`; no automatic login, no port
      forwarding, no public exposure. Idempotent on re-run; omitting the flag
      does not remove Tailscale
- [x] The installer prints the `tailscale up --auth-key ... --advertise-tags`
      command instead of handling the key itself
- [x] Keep `8080` LAN-bound as today; document access via the tailnet address and
      the MagicDNS name
- [x] Document that Tailscale does **not** replace broker authentication and does
      not make the default `admin/domoticz` credentials acceptable
- [x] Document ACL/tag scheme, how to revoke a node, and how to run LAN-only
      without Tailscale at all
- [ ] Resource check on the Zero 2 W (`tailscaled` RSS, startup time) and note
      the SD-card write impact
- [x] Documentation: `docs/tailscale.md` — threat model, install, ACL example,
      firewall interaction with `tailscale0`, revocation, uninstall
- [x] README: flag entry plus the documentation index, with the threat model in
      `docs/tailscale.md` (no HTTPS on the Pi, so no exposure outside the tailnet)
- [ ] Test on hardware: `--tailscale` install, `tailscaled` active, UI reachable
      from a tailnet device, nothing reachable from the internet

Acceptance criteria: the UI answers on the tailnet address from an authorized
device, nothing answers from the internet without Tailscale, and revoking the
node cuts access immediately.

## P2 — Versioning and documentation

### 11. Tag and GitHub Release

- [x] `v1.0.0` — Pi Zero W (ARMv6) reference
      (<https://github.com/kszymczycha/domoticz-pi/releases/tag/v1.0.0>)
- [x] Merge `feat/zero2w` and tag `v2.0.0`
- [x] Publish `v2.0.0` as a **pre-release** with `setup_domoticz.sh` +
      `SHA256SUMS` (<https://github.com/kszymczycha/domoticz-pi/releases/tag/v2.0.0>)
- [ ] Test `v2.0.0` on a real Raspberry Pi Zero 2 W, record the test date, and
      promote it to a full release
- [x] README points at the **release asset** of the current line
      (`v2.1.0-rc2` on `release/v2.1.0`; `main` still points at `v2.0.0`)
- [x] `release/v2.1.0` prepared: `feat/mqtt-auth`, `feat/zigbee-docs`, and
      `feat/tailscale-flag` merged, `CHANGELOG.md` written, README "Tested on"
      filled with `PENDING HARDWARE TEST`
- [x] Publish `v2.1.0-rc1` as a **pre-release** (superseded by `rc2`)
- [x] Publish `v2.1.0-rc2` as a **pre-release** with the review fixes
      (listener check, Quadlet keys, docs); run the hardware test list from
      `README.md` next
- [ ] Promote to `v2.1.0`: update the "Tested on" rows and the `CHANGELOG`
      pending list with the test date and results
- Note: do not host Domoticz binaries in releases — GPLv3 requires offering the
  source

### 12. README

- [x] "Tested on" section: board, OS, Domoticz/Z2M versions, each row marked
      `PENDING HARDWARE TEST` until the release candidate is validated
- [x] "Uninstall" section
- [x] "License" section → `LICENSE` (MIT)
- [x] Documentation index pointing at `docs/zigbee2mqtt.md` and `docs/tailscale.md`
- [ ] Panel screenshot (optional)

## P3 — Zigbee 3 via Zigbee2MQTT (local Tuya control)

Goal: control Tuya Zigbee devices from Domoticz **locally**, with no cloud
round-trip, through exactly one path:

```
SONOFF Zigbee/Thread USB Dongle Plus MG24 (EFR32MG24, EZSP)
   -> Zigbee2MQTT  ->  Mosquitto  ->  Domoticz
```

Scope note: this repository is an installer. Integration work is
documentation-first; add script support only where it is genuinely reusable.
Do not bloat `setup_domoticz.sh` with device-specific logic.

Out of scope for now (recorded so it is not relitigated):
Tuya Wi-Fi devices (`tinytuya`/local API), the Tuya cloud and the Tuya gateway
bridge, deCONZ, Thread/Matter and OpenThread border routers, and any other
coordinator. The MG24 is used in Zigbee coordinator mode only. Revisit only if
the Zigbee2MQTT path cannot cover a specific device.

### 13. Discovery (do this first)

- [ ] Record the SONOFF Dongle Plus MG24 details: exact model/revision, the
      factory firmware image, and the flasher used (SONOFF Dongle Flasher)
- [ ] Flash coordinator firmware **8.0.2** before first start and record the
      exact file/version string in the docs as a prerequisite. Factory 7.4.5 is
      not the tested baseline; MultiPAN firmware is not used
- [ ] Confirm the dongle is detected on the Pi Zero 2 W (`/dev/ttyACM0` or
      `/dev/ttyUSB0`), that the port can power it, and that the serial path is
      stable across reboots (`/dev/serial/by-id/...`)
- [ ] Confirm the Zigbee2MQTT adapter setting is `ember` (EZSP-style `ezsp` is
      not used) with `baudrate: 115200`, and that the pinned Z2M release
      supports coordinator firmware 8.0.2
- [ ] Inventory the Tuya Zigbee devices (sockets, relays, sensors) and confirm
      each model is in the Z2M supported-devices list without custom quirks
- [x] Confirm the Domoticz side of the wiring: hardware type **MQTT Auto
      Discovery Client Gateway with LAN interface** and the field **"MQTT
      Discovery Prefix"** set to `homeassistant` (verified in the UI)
- [ ] Record how far that gateway gets with this Z2M version: which device types
      are created automatically and which appear as unused or not at all

Open questions: see "Open questions" below (the P3 decisions are recorded
there and in "Decisions").

### 14. Zigbee2MQTT and Mosquitto stack

- [ ] Run Zigbee2MQTT as a Podman container from the **official image pinned by
      tag** (Node.js comes from the image; no system Node.js). Podman is
      therefore required for the Zigbee path even on the native Domoticz
      install
- [ ] Record image tag and digest in the docs; a version bump is a deliberate,
      tested change
- [ ] `configuration.yaml`: `serial.adapter: ember`, `serial.baudrate: 115200`,
      `serial.port` via `/dev/serial/by-id/...`, `mqtt.server` + credentials from
      P1.7, `mqtt.base_topic`
- [ ] `frontend: false` by default to save RAM; enable it temporarily only for
      pairing or troubleshooting
- [ ] `permit_join: false` by default; open a pairing window explicitly and
      close it afterwards
- [ ] Cap memory for the Z2M container (Podman `--memory`) so an OOM cannot take
      down Domoticz, and document how to raise it
- [ ] Ensure Domoticz and Z2M use the same broker and topic prefix; configure the
      Domoticz hardware entry once and record which one works
- [ ] Verify QoS/retain settings so device states survive a Domoticz restart
- [ ] Resource check: measure RSS/CPU of Z2M on the Zero 2 W with the frontend
      off, under pairing load and after a reboot
- [x] Documentation: `docs/zigbee2mqtt.md` — firmware 8.0.2, `ember` at 115200,
      serial path, USB extension cable as a hard requirement, pinned image,
      Quadlet unit with `Memory=200m`, MQTT-based pairing, Domoticz AD setup,
      backup/upgrade/uninstall, troubleshooting

### 15. Pairing, naming, and Domoticz mapping

- [x] Primary integration: native **MQTT Auto Discovery Client Gateway**. Devices
      are created from Z2M discovery topics once state arrives
- [ ] Record the proven behaviour per device class (socket, relay, sensor) and
      list any type that falls back to manual mapping
- [x] Fallback rule: manual topic mapping is allowed **only** for a specific
      device that auto discovery cannot represent; the Python
      `domoticz-zigbee2mqtt` plugin is rejected as maintenance overhead
- [x] Document pairing: dongle in coordinator mode, pairing window, device reset,
      confirmation in Z2M logs/CLI
- [x] Naming convention in Z2M and how it maps to Domoticz names; no
      device-specific hardcoding in the installer
- [ ] Confirm a paired Tuya device appears in Domoticz and responds to commands
      with the internet uplink blocked
- [x] Document removal/re-pair and recovery after a dongle replacement or a lost
      Zigbee network key
- [x] Documentation: "Device Support" table in `docs/zigbee2mqtt.md` with
      placeholder rows for Tuya sockets, relays, and sensors to be verified on
      hardware

### 16. Security and operations

- [ ] Broker authentication is mandatory (depends on P1.7); no anonymous access
      for Z2M or Domoticz
- [x] The Zigbee network key, MQTT credentials, and the Z2M `data/` directory
      never enter the repository; documented where they live on the device
- [x] Backup: `tar` of the Z2M `data/` directory plus `domoticz.db`, with a
      documented restore order
- [ ] Test recovery after a reboot, after a broker restart, and after a dongle
      reconnect (state restored, no duplicate devices)
- [x] Upgrade procedure: pinned image bump, coordinator firmware updates, and the
      rollback step
- [x] Document the USB extension cable as a **hard requirement**: the dongle must
      be physically separated from the Pi and its power supply; pairing results
      without it are not accepted

Acceptance criteria:

- A Tuya Zigbee device pairs through the MG24 dongle (firmware 8.0.2, adapter
  `ember`), is created by MQTT Auto Discovery in Domoticz, and responds to
  commands with the internet uplink blocked.
- A state change made on the device reaches Domoticz within the documented
  interval and survives a reboot of the Pi.
- The whole chain is Zigbee2MQTT -> Mosquitto -> Domoticz only; no Tuya cloud
  account is needed for day-to-day control.
- The stack fits in 512 MB RAM with the Z2M frontend disabled; no OOM kill in a
  24-hour run.
- No credentials or keys in the repository; the broker rejects anonymous
  clients.

## P4 — Container deployment (Podman)

Goal: the target deployment of the whole chain — Domoticz, Mosquitto, and
Zigbee2MQTT — as Podman containers on the Pi Zero 2 W, with `systemd`/Quadlet
units for autostart. This replaces the native `/opt` + `/var/lib` layout and is
therefore a **major release (`v3.0.0`)**: the database path moves to a volume.

Podman runs **rootful** (as root). This is a deliberate choice: passing the MG24
dongle to the container and dealing with `dialout` ownership is far simpler and
more reproducible than rootless with `--group-add keep-groups`. The trade-off
(container root equals host root) must be documented, not hidden.

Zigbee2MQTT runs as a container from P3.14 onwards. This section turns the
native Domoticz + Mosquitto install into containers and makes the container
layout the supported one.

Scope note: `setup_domoticz.sh` must not grow container logic — a separate
script or a documented Quadlet/compose set is preferred. The native install
remains available for `v2.x` users; both modes never run on the same host.

### 17. Containerised deployment

- [ ] Confirm `podman` and Quadlet support are recent enough on Raspberry Pi OS
      Lite 64-bit (Trixie), and that the official `domoticz/domoticz` image has
      an `arm64` variant at the pinned tag
- [ ] Measure the overhead against the native install (RAM, CPU, startup time,
      SD-card writes) on a 512 MB board
- [ ] Persist state in named volumes: `domoticz.db`, plugins, scripts, Z2M
      `data/`, and the Mosquitto config plus password file. Never inside the
      container layer
- [ ] Networking: publish 8080 on the LAN; keep MQTT on a Podman network between
      the three containers; publish 1883 only when `--mqtt-lan` semantics apply
- [ ] USB passthrough for the MG24 dongle in rootful mode (`--device`), plus the
      `/dev/serial/by-id/` path inside the container and a reboot test
- [ ] Autostart and recovery: Quadlet `.container` units, `Restart=always`,
      ordering (broker -> Z2M -> Domoticz), and logs in the journal
- [ ] Backup/restore: snapshot the volumes and document migration from the
      native layout in both directions, including the `domoticz.db` path change
- [ ] Document the security delta versus the hardened systemd unit: rootful
      containers run as root, so `NoNewPrivileges`, `ProtectSystem=strict`, and
      `ReadWritePaths` need explicit `--cap-drop`, read-only mounts, and
      `--security-opt` equivalents
- [ ] Document image pinning by tag **and** digest, and the upgrade/rollback
      procedure for all three containers
- [ ] README: a "Podman instead of the native install" section with an explicit
      "pick one" warning (two deployments writing the same database is unsafe)

Acceptance criteria:

- All three containers start from Quadlet units after a reboot, Domoticz serves
  the UI on port 8080, and the database survives container replacement.
- Z2M sees the MG24 dongle (firmware 8.0.2, `ember`) and delivers device updates
  to Domoticz through the containerised Mosquitto with authentication enabled.
- Removing the containers leaves no orphaned data, and migrating the database
  back to the native layout works.
- The documented security delta is honest: no capabilities beyond the listed
  `--cap-drop`/read-only baseline, and no host network access where a Podman
  network works.

## Open questions

Decisions taken on 2026-11-18 are recorded here so the rationale sits next to
the roadmap; the binding summary is in "Decisions".

### Resolved

| # | Question | Decision |
| --- | --- | --- |
| 1 | How does Domoticz consume Zigbee2MQTT? | Native **MQTT Auto Discovery Client Gateway** only. Manual topic mapping is a per-device fallback if auto discovery fails for a type; the Python `domoticz-zigbee2mqtt` plugin is rejected (maintenance). |
| 2 | Which coordinator firmware? | Flash **8.0.2** before first start; version is a documented prerequisite. Adapter is **`ember`**, never `ezsp`. MultiPAN firmware is not used. |
| 3 | Where does the stack run? | Entirely on the Pi Zero 2 W. Zigbee2MQTT runs as a Podman container **from the start** with `--memory=200m`; frontend disabled. No second host. |
| 4 | Auth before or after Z2M? | **P1.7 first**, then Z2M. No temporary anonymous broker. |
| 5 | Podman rootless or rootful? | **Rootful.** USB passthrough and `dialout` are simpler and reproducible; the trade-off is documented. All three services containerised in **v3.0.0** (major, layout change). |
| 6 | Device scope | Tuya Zigbee sockets, relays, and sensors only; assumed in the Z2M supported-devices list with no custom quirks. |
| 7 | USB extension cable | **Hard requirement.** The dongle must be away from the Pi and its PSU; tests without it are invalid. |
| 8 | Z2M versioning and Node.js | Pin the **official image by tag and digest**; Node.js comes from the image. No system Node.js. Z2M is containerised from the start (confirmed), so Podman is a requirement of the Zigbee path. |
| 9 | Backups | One script: `tar` of Z2M `data/` plus `domoticz.db`, with a documented restore order. |
| 10 | Remote access | **Tailscale** VPN (P1.10). No port forwarding, no public exposure. |
| 11 | Domoticz AD wiring | Hardware type "MQTT Auto Discovery Client Gateway with LAN interface"; field **"MQTT Discovery Prefix"** = `homeassistant`. Verified in the UI; documented in `docs/zigbee2mqtt.md` section 8. |

### Still open

- **Auto-discovery coverage:** which Tuya types (thermostats, covers, multi-gang
  switches) are actually created by Domoticz auto discovery. The hardware type
  and the `MQTT Discovery Prefix` field are confirmed; the per-device coverage is
  only measurable with the devices on the desk, and the fallback list depends on
  it.
- **Firmware pinning mechanics:** the SONOFF flasher is browser-based, so there
  is no checksum to embed. Decide whether to record only the version string or
  also archive the firmware file and its SHA256 in the docs.
- **Z2M image availability for `arm64`:** the guide assumes the pinned tag
  publishes an `arm64` manifest; confirm it on the board (and record the digest
  that was actually used).
- **RAM headroom:** real RSS of containerised Z2M + Podman + Domoticz on 512 MB,
  including a pairing burst and a 24-hour run.
- **Podman on Trixie:** Quadlet version, cgroup delegation, and whether extra
  kernel parameters are needed for the memory cap.
- **SD-card wear:** whether Z2M plus Domoticz logging on the SD card requires
  journald tuning or a log-to-RAM option.
- **Tailscale footprint:** `tailscaled` RSS on the Zero 2 W (the step itself is
  already optional via `--tailscale`).
- **Release shape for P4:** a separate script, Quadlet files in the repo, or a
  documented compose file — and whether native and container modes share a
  migration tool.
- **`--mqtt-lan` after containerisation:** whether the flag keeps its meaning
  when the broker is containerised, or is replaced by a Podman network plus an
  explicit publish rule.

## Suggested order

1. **Hardware test of `v2.1.0-rc2`** — run the `PENDING HARDWARE TEST` list from
   the README on the real Pi Zero 2 W with the MG24 dongle, update the rows and
   the `CHANGELOG`, then tag `v2.1.0` from `release/v2.1.0` (and promote
   `v2.0.0` in the same session if it passes)
2. **`v2.1.0` documentation merge** — merge `release/v2.1.0` into `main`, point
   the README at the final asset, publish the full release
3. **P4.17** — containerise the whole chain with rootful Podman, released as
   `v3.0.0`

## Acceptance criteria

- **v2.0.0:** a fresh Raspberry Pi OS Lite 64-bit install succeeds on a Zero 2 W;
  an existing `/var/lib/domoticz/domoticz.db` is preserved; the web UI answers on
  port 8080 after a reboot; the service starts under the `domoticz` user; the
  unit passes a `systemd-analyze security` review; Mosquitto is active.
- **v2.1.0:** everything above, plus authenticated MQTT with the listener
  localhost-only by default; `--mqtt-lan`, `--help`, and `--tailscale` behave as
  documented; a Tuya Zigbee device pairs through the MG24 and is created in
  Domoticz by MQTT Auto Discovery with the uplink blocked.
- **7 (Mosquitto):** anonymous publish is rejected; publishing with the generated
  credentials succeeds; re-running the installer does not rotate credentials; the
  listener is localhost-only without `--mqtt-lan` and `0.0.0.0` with it; the
  documented Domoticz setup works on a fresh install.
- **9 / 12:** README-only changes; acceptance means the documented commands work
  on a fresh install.
- **10 (Tailscale):** the UI answers on the tailnet address from an authorized
  device; nothing answers from the internet without Tailscale; revoking the node
  cuts access.
- **13–16 (Zigbee):** see the P3 acceptance criteria above; the origin is
  firmware 8.0.2 with adapter `ember` and devices arrive through MQTT Auto
  Discovery.
- **17 (Podman, `v3.0.0`):** all three containers start after a reboot, the
  database and Z2M `data/` live in volumes, and migration back to the native
  layout is documented and tested once.

## Decisions

Decided on 2026-11-12:

- **Mosquitto credentials:** generate a random password (`openssl rand -hex 16`),
  create user `domoticz`, and print the credentials once at the end. Never rotate
  an existing password file on re-run; report "existing credentials unchanged".
- **Broker exposure:** localhost-only by default. LAN access requires the
  explicit `--mqtt-lan` flag, which adds `listener 1883 0.0.0.0` together with
  authentication and a firewall hint.
- **`PLAN.md`:** stays in the repository while the project is small.

Decided on 2026-11-16:

- **Drop the Pi Zero W:** after the `v1.0.0` reference release, the project
  targets the Raspberry Pi Zero 2 W only. `maint/1.x` is end-of-life and receives
  no backports.
- **OS baseline:** 64-bit Raspberry Pi OS Lite, Debian 12 or newer, OpenSSL 3.
  The installer rejects `armv6l` and `armv7l`.
- **Official artifacts:** use the upstream Domoticz `aarch64` release instead of
  the community ARMv6 binary and the Buster `libssl1.1` workaround.
- **Layout (P1.8):** adopt `/opt/domoticz` + `/var/lib/domoticz` in `v2.0.0`
  together with a dedicated system user and a hardened unit. There is no
  automatic migration from the old `$HOME` layout; moving `domoticz.db` is a
  documented manual step.
- **Logging:** use the systemd journal; no file-based logrotate rule.

Open decisions: none outstanding; unresolved facts are tracked in
"Open questions".

Decided on 2026-11-18:

- **Single integration path:** Tuya Zigbee devices are controlled locally through
  `Zigbee2MQTT -> Mosquitto -> Domoticz` using the SONOFF Dongle Plus MG24 as
  coordinator. Tuya Wi-Fi (`tinytuya`), the Tuya cloud, the Tuya gateway bridge,
  deCONZ, and Thread/Matter are out of scope until this path is proven.
- **Domoticz integration:** native MQTT Auto Discovery Client Gateway. Manual
  topic mapping only for a specific device that auto discovery cannot represent;
  the Python plugin is rejected as maintenance overhead.
- **Coordinator firmware:** 8.0.2 is a documented prerequisite; adapter `ember`
  only. MultiPAN firmware is not used.
- **Topology:** everything on the Pi Zero 2 W; Z2M frontend disabled by default
  and a container memory cap as the OOM guard. No second host.
- **Order:** Mosquitto authentication (P1.7) lands before any Zigbee work.
- **Zigbee2MQTT packaging:** official image pinned by tag and digest, Node.js
  from the image. Z2M is containerised from the start, with `--memory=200m` and
  the frontend disabled, so Podman is part of the Zigbee path, not just P4.
- **Podman mode:** rootful. The whole chain (Domoticz, Mosquitto, Z2M) is
  containerised as the `v3.0.0` target; the native layout stays supported for
  `v2.x`.
- **Radio hygiene:** a USB extension cable and physical separation from the Pi
  are mandatory; pairing results without them are invalid.
- **Remote access:** Tailscale VPN only (P1.10), no port forwarding.

## Versioning and hardware support

One release line for one supported board family. Hardware support is validated
at install time, not branched per board.

Semantic versioning for this project (the "public API" is the CLI, the install
layout, and the database location):

| Change | Bump |
| --- | --- |
| New compatible feature or flag | minor |
| Pinned artifact bump, bug fix, wording | patch |
| Install layout change, removed flag, dropped board support | major |

Release lines:

- **`v1.0.0`** — frozen reference for the Raspberry Pi Zero W (ARMv6 only).
  Historical, unsupported, and never deleted. Use it to roll back the old
  hardware.
- **`maint/1.x`** — end-of-life branch kept for history. Do not merge into it or
  cherry-pick fixes.
- **`main`** — the Raspberry Pi Zero 2 W line. `v2.0.0` is the first release
  (aarch64, `/opt` layout). Future releases are `v2.x.y`; dropping Zero 2 W
  support or changing the layout again requires a new major.
- **`v2.1.0`** — MQTT authentication, the Zigbee2MQTT path (documented;
  Zigbee2MQTT itself runs as a container), and the optional Tailscale step.
  Currently `v2.1.0-rc2` on `release/v2.1.0`, pending the hardware test.
- **`v3.0.0`** — the containerised layout (rootful Podman: Domoticz, Mosquitto,
  Zigbee2MQTT). Changing the install layout again or dropping Zero 2 W support
  requires a further major.

Rules:

- No permanent per-board branches and no hardware suffix in tag names; the tag
  message and release notes record the supported board and OS.
- Annotated tags for every release (`git tag -a`, sign once a GPG key is
  configured); protect `v*` tags and push the explicit tag ref.
- Release notes state the supported board, Domoticz version, Raspberry Pi OS
  version, and the test date.
- Rolling back: `git switch --detach v1.0.0` for the old board, or install from
  the pinned release asset. Keep a tested copy of the installer on the device for
  offline recovery.

## Branch workflow

- While the repository has a single maintainer, documentation and small fixes go
  straight to `main` after a green CI run.
- The Zero 2 W port is merged on `main`. `v2.0.0` stays a pre-release until a
  successful test on a real Raspberry Pi Zero 2 W; promote it to a full release
  afterwards. Fix forward with patch releases if the test finds issues.
- Release candidates live on `release/vX.Y.Z`: features merge there with
  `--no-ff`, an RC gets an annotated tag and a GitHub **pre-release**, and the
  final tag is created only after the hardware test. `v2.1.0` uses this flow
  (`v2.1.0-rc1`, superseded by `v2.1.0-rc2`).
- Feature branches (`feat/*`, `fix/*`) are pushed for review and merged into the
  release branch or `main`; they are not permanent.
- `maint/1.x` is frozen. Do not use it for new work.
- Keep `main` releasable; never force-push `main` except for history rewrites
  agreed in advance.

## Verification before every merge

- `bash -n setup_domoticz.sh`
- `shellcheck setup_domoticz.sh` (zero findings) — install it locally
  (`sudo apt-get install shellcheck`) or rely on the CI workflow
- failure-path test: running without root exits with code 1
- CLI test: `--help` exits 0, an unknown flag exits 2 and prints usage
- CI covers `main` and `release/**`; a green run is a merge gate, not a
  substitute for the hardware test
- after install-flow changes: test on a real Raspberry Pi Zero 2 W with
  Raspberry Pi OS Lite 64-bit (Debian 12 or newer)
