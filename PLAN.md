# Development Roadmap

Status as of 2026-11-16:

- `v1.0.0` is the frozen Raspberry Pi Zero W (ARMv6) reference.
- The current line targets the Raspberry Pi Zero 2 W only: `v2.0.0` is merged
  to `main` and published as a pre-release. It awaits a hardware test before
  being promoted to a full release.

**Next action:** test `v2.0.0` on a real Raspberry Pi Zero 2 W (clean Raspberry
Pi OS Lite 64-bit, install, web UI on port 8080, reboot, database persistence,
`systemd-analyze security`, Mosquitto active). On success, unmark the GitHub
pre-release, add the test date to the release notes, README, and this file.
If the board is not available yet, continue with **P1.7 (Mosquitto
authentication)** on `main`; the hardware test remains the gate for promoting
`v2.0.0`.

## Context for the next session

- Target: Raspberry Pi Zero 2 W, 64-bit Raspberry Pi OS Lite (aarch64, Debian
  12 or newer; Trixie is current), with SSH access and a `sudo` user.
- The script performs eight steps: preflight validation -> system update and
  dependencies -> download and verify the pinned release -> service account and
  directories -> install files -> systemd unit -> Mosquitto -> verify.
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
- Maintenance procedure: `.opencode/skills/domoticz-zero2w/SKILL.md`; keep it in
  sync with this plan.

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
- [x] **P2.10** ShellCheck CI (`.github/workflows/shellcheck.yml`)
- [x] **P2.11 (v1.0.0)** Tag and GitHub release for the Pi Zero W reference
- [x] **v2.0.0 port** Domoticz 2026.4 aarch64, platform validation, no ARMv6
      workarounds, pinned artifact and checksum
- [x] **P1.8 (layout)** `/opt/domoticz`, `/var/lib/domoticz`, dedicated system
      user, hardened unit, journal logging
- [x] README: current board/OS, install from the release asset, layout, backup,
      database migration, firewall hint, uninstall

## P1 — Reliability and security

### 7. Mosquitto configuration

The broker is installed and enabled, but authentication is not configured yet:

- [ ] `/etc/mosquitto/conf.d/domoticz.conf`: `allow_anonymous false`, `password_file /etc/mosquitto/passwd`
- [ ] Add `--mqtt-lan` and `--help` flags to the installer
- [ ] Create the `domoticz` MQTT user with a generated password (`openssl rand -hex 16`), printed once; skip creation if the password file already exists
- [ ] Require `openssl` (already used for the version check)
- [ ] `listener 1883 0.0.0.0` only behind `--mqtt-lan`
- [ ] Restart Mosquitto after writing the config and verify auth: anonymous publish rejected, authenticated publish accepted
- [ ] README: how to add the broker as a "hardware" entry in Domoticz and how to add more devices
- [ ] README: clear warning that enabling auth requires configuring credentials in Domoticz/ESP, otherwise things stop working

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

### 9. Network exposure and default credentials

- [x] README: port 8080 listens on `0.0.0.0`; show `ufw allow from <LAN> to any port 8080`
- [x] README: stronger warning about `admin/domoticz`
- [ ] With `--mqtt-lan`, print the `ufw` rule for port 1883 and warn if the firewall is inactive (never install `ufw` silently)

## P2 — Versioning and documentation

### 11. Tag and GitHub Release

- [x] `v1.0.0` — Pi Zero W (ARMv6) reference
      (<https://github.com/kszymczycha/domoticz-pi/releases/tag/v1.0.0>)
- [x] Merge `feat/zero2w` and tag `v2.0.0`
- [x] Publish `v2.0.0` as a **pre-release** with `setup_domoticz.sh` +
      `SHA256SUMS` (<https://github.com/kszymczycha/domoticz-pi/releases/tag/v2.0.0>)
- [ ] Test `v2.0.0` on a real Raspberry Pi Zero 2 W, record the test date, and
      promote it to a full release
- [x] README points at the **v2.0.0 release asset**
- Note: do not host Domoticz binaries in releases — GPLv3 requires offering the
  source

### 12. README

- [ ] "Tested on" section: date, board, Raspberry Pi OS version, Domoticz version
- [x] "Uninstall" section
- [ ] "License" section → `LICENSE` (MIT)
- [ ] Panel screenshot (optional)

## P3 — Device integrations (Tuya Wi-Fi and Zigbee 3)

Goal: control Tuya Wi-Fi devices and Zigbee 3 devices (through the existing
gateway) from Domoticz.

Scope note: this repository is an installer. Integration work is
documentation-first; add script support only where it is genuinely reusable.
Do not bloat `setup_domoticz.sh` with device-specific logic.

### 13. Discovery (do this first)

- [ ] Record the gateway brand, model, firmware, and supported local interfaces
      (MQTT bridge, local API, Matter, cloud-only)
- [ ] Inventory the Tuya Wi-Fi devices and check whether local keys can be
      extracted
- [ ] Decide whether the Zigbee stack runs on the Pi Zero 2 W or on a more
      capable always-on host

Open questions:

- Is the gateway Tuya-branded and cloud-only, or does it expose a local/MQTT
  bridge?
- Is cloud dependency acceptable for Tuya Wi-Fi devices, or is local-only
  control required?
- Is there a spare always-on host for Zigbee2MQTT, or must everything run on the
  Pi Zero 2 W (512 MB RAM)?

### 14. Tuya Wi-Fi

- [ ] Prefer local control (`tinytuya` / local API) over the Tuya cloud
- [ ] Document how to obtain the device ID and local key without committing
      secrets
- [ ] Map devices to Domoticz (MQTT topics or a Python plugin) and document
      naming
- [ ] Define polling interval and reconnect behavior after network loss

### 15. Zigbee 3 (existing gateway)

- [ ] If the gateway exposes MQTT, bridge it to Domoticz through Mosquitto
- [ ] Otherwise document the supported path (Zigbee2MQTT coordinator, deCONZ, or
      the gateway's cloud)
- [ ] Resource check: Zigbee2MQTT (Node.js) is still heavy for a Zero 2 W;
      prefer an external host and enable `--mqtt-lan`
- [ ] Document pairing and device naming in Domoticz

### 16. Security and operations

- [ ] Broker authentication is mandatory (depends on P1.7); no anonymous access
- [ ] Cloud credentials and device keys never enter the repository; document
      where they live
- [ ] Backups cover device pairing data, not only `domoticz.db`
- [ ] Test recovery after a reboot and after a broker restart

Acceptance criteria:

- A Tuya Wi-Fi device state change round-trips to Domoticz within the documented
  interval and survives a reboot.
- Zigbee devices pair through the gateway and appear in Domoticz.
- No credentials in the repository; the broker rejects anonymous clients.

## Suggested order

1. **P2.11 (v2.0.0)** — test the pre-release on a real Zero 2 W and promote it
   to a full release
2. **7** — Mosquitto auth (code + README MQTT section)
3. **9 + 12** — README only (MQTT firewall hint, Tested on, License)
4. **13–16** — device integrations (docs + optional helpers), released as v2.1.0

## Acceptance criteria

- **v2.0.0:** a fresh Raspberry Pi OS Lite 64-bit install succeeds on a Zero 2 W;
  an existing `/var/lib/domoticz/domoticz.db` is preserved; the web UI answers on
  port 8080 after a reboot; the service starts under the `domoticz` user; the
  unit passes a `systemd-analyze security` review; Mosquitto is active.
- **7 (Mosquitto):** anonymous publish is rejected; publishing with the generated
  credentials succeeds; re-running the installer does not rotate credentials; the
  listener is localhost-only without `--mqtt-lan` and `0.0.0.0` with it; the
  documented Domoticz setup works on a fresh install.
- **9 / 12:** README-only changes; acceptance means the documented commands work
  on a fresh install.

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
- **`v3.0.0`** — reserved for the next breaking change, if any.

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
- `maint/1.x` is frozen. Do not use it for new work.
- Keep `main` releasable; never force-push `main` except for history rewrites
  agreed in advance.

## Verification before every merge

- `bash -n setup_domoticz.sh`
- `shellcheck setup_domoticz.sh` (zero findings) — install it locally
  (`sudo apt-get install shellcheck`) or rely on the CI workflow
- failure-path test: running without root exits with code 1
- after install-flow changes: test on a real Raspberry Pi Zero 2 W with
  Raspberry Pi OS Lite 64-bit (Debian 12 or newer)