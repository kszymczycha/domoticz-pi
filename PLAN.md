# Development Roadmap

Status as of 2026-11-12 (code state: `f424e12`, `Harden ARMv6 setup script and add ShellCheck CI`).

## Context for the next session

- All repository content (README, PLAN, code comments, commit messages) is
  written in English.
- The script performs seven steps: system update -> legacy libraries -> extract
  release -> swap in the ARMv6 binary -> systemd service -> Mosquitto -> verify.
  Keep that order.
- Local checks: `bash -n setup_domoticz.sh` plus CI ShellCheck. ShellCheck is not
  installed locally; the workflow on `ubuntu-latest` is the authoritative check.
- Pinned artifacts live at the top of `setup_domoticz.sh`. To bump Domoticz,
  update the version/URL and recompute the checksums:

  ```bash
  curl -sSL -o /tmp/domoticz.tgz "$DOMOTICZ_TARBALL_URL"
  curl -sSL -o /tmp/domoticz.bin "$DOMOTICZ_BINARY_URL"
  sha256sum /tmp/domoticz.tgz /tmp/domoticz.bin
  ```

  Then update both constants and commit the bump as one change.
- Do NOT: host Domoticz binaries in releases (GPLv3 source obligation), use
  mutable URLs, or reintroduce CRLF line endings.
- Known gap until P2.11: the README still downloads the script from `main`.
- `git log` is the source of truth for status; the Done list below is a snapshot.
- Maintenance procedure: `.opencode/skills/domoticz-armv6/SKILL.md`; keep it in
  sync with this plan.

## Done

- [x] Squashed history into an `Initial commit` plus a dedicated hardening commit
- [x] README cleanup (removed draft artifact) and correct file permissions
- [x] Line endings normalized to LF + `.gitattributes` (CRLF previously broke the `#!` line)
- [x] **P0.1** `set -euo pipefail` + `trap ... ERR` reporting the failing line
- [x] **P0.2** Idempotent adding/commenting of the Buster repository
- [x] **P0.3** Pinned artifacts (commit `b24a421…`, version `2024.4`) + SHA256 verification
- [x] **P0.4** Validation of `armv6l`, `SUDO_USER`, required commands, free space (512 MB)
- [x] **P0.5** `DEBIAN_FRONTEND=noninteractive`
- [x] **P1.6** Safe `TARGET_USER` detection (`getent`, no `admin` fallback)
- [x] **P2.10** ShellCheck CI (`.github/workflows/shellcheck.yml`)

## P1 — Reliability and security

### 7. Mosquitto configuration

The broker is currently only installed. To do:

- [ ] `/etc/mosquitto/conf.d/domoticz.conf`: `allow_anonymous false`, `password_file /etc/mosquitto/passwd`
- [ ] Add `--mqtt-lan` and `--help` flags to the installer
- [ ] Create the `domoticz` MQTT user with a generated password (`openssl rand -hex 16`), printed once; skip creation if the password file already exists
- [ ] Require `openssl` (add it to the `require_cmd` checks)
- [ ] `listener 1883 0.0.0.0` only behind `--mqtt-lan` (see Decisions)
- [ ] Restart Mosquitto after writing the config and verify auth: anonymous publish rejected, authenticated publish accepted
- [ ] README: how to add the broker as a "hardware" entry in Domoticz and how to add more devices
- [ ] README: clear warning that enabling auth requires configuring credentials in Domoticz/ESP, otherwise things stop working

Out of scope: TLS — its performance cost on a Pi Zero is disproportionate for a home LAN.

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

### 8. Separate binary, data and logs

Everything currently lands in `$HOME`. Target layout:

- [ ] `/opt/domoticz` — binary, `www`, `plugins`, `dzVents`, `scripts`
- [ ] `/var/lib/domoticz` — `domoticz.db`, logs
- [ ] Dedicated `domoticz` system user instead of a login account
- [ ] Unit hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=true`, `ReadWritePaths=/var/lib/domoticz`
- [ ] Logrotate for file-based logs (if Domoticz writes to `domoticz.log`)
- [ ] Migration path from the old `$HOME` install: detect `domoticz.db`, back it up, move it
- [ ] Migration policy — see Decisions (automatic migration with a timestamped backup)

**Risk: high.** Requires testing on a real Pi Zero; do it on a separate branch.

### 9. Network exposure and default credentials

- [ ] README: port 8080 listens on `0.0.0.0`; show `ufw allow from <LAN> to any port 8080`
- [ ] README: stronger warning about `admin/domoticz`
- [ ] With `--mqtt-lan`, print the `ufw` rule for port 1883 and warn if the firewall is inactive (never install `ufw` silently)

## P2 — Versioning and documentation

### 11. Tag and GitHub Release

- [ ] `git tag -a v1.0.0` + push tags
- [ ] Release with assets: `setup_domoticz.sh` + `SHA256SUMS`
- [ ] README: download the script from the **release** instead of `main` (today `main` is another mutable URL)
- [ ] Do not host Domoticz binaries in releases — GPLv3 requires offering the source

### 12. README

- [ ] "Tested on" section: date, Pi model, Raspberry Pi OS version, Domoticz version
- [ ] "Uninstall" section: `systemctl disable`, remove files, revert the Buster repository entry, `apt remove mosquitto`
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
- [ ] Decide whether the Zigbee stack runs on the Pi Zero W or on a more capable
      always-on host

Open questions:

- Is the gateway Tuya-branded and cloud-only, or does it expose a local/MQTT
  bridge?
- Is cloud dependency acceptable for Tuya Wi-Fi devices, or is local-only
  control required?
- Is there a spare always-on host for Zigbee2MQTT, or must everything run on the
  Pi Zero W (512 MB RAM)?

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
- [ ] Resource check: Zigbee2MQTT (Node.js) is heavy for a Pi Zero W; prefer an
      external host and enable `--mqtt-lan`
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

1. **7** — Mosquitto (code + README MQTT section), so documentation matches behavior
2. **9 + 12** — README only (firewall, Uninstall, Tested on, License)
3. **11** — tag/release once behavior is final (installer v1.0.0)
4. **13–16** — device integrations (docs + optional helpers), released as v1.1.0
5. **8** — last, separate branch, tested on the device

## Acceptance criteria

- **7 (Mosquitto):** anonymous publish is rejected; publishing with the generated
  credentials succeeds; re-running the installer does not rotate credentials; the
  listener is localhost-only without `--mqtt-lan` and `0.0.0.0` with it; the
  documented Domoticz setup works on a fresh install.
- **8 (Layout):** a fresh install runs from `/opt/domoticz` and
  `/var/lib/domoticz`; an existing `$HOME` install migrates with a timestamped
  database backup and aborts if the backup cannot be created; the service passes
  `systemd-analyze security` review.
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
- **Layout migration (P1.8):** detect an existing `$HOME/domoticz.db`, create a
  timestamped backup, then migrate to `/var/lib/domoticz`; abort with
  instructions if the backup fails. Never silently overwrite an existing
  database.

## Branch workflow

- While the repository has a single maintainer, P1.7, P2.9, P2.11, P2.12 and
  P3 documentation changes go straight to `main` after a green CI run.
- P1.8: branch `refactor/layout`, manual test on a real Pi Zero, merge only after
  that test passes.
- Keep `main` releasable; never force-push `main` except for history rewrites
  agreed in advance.

## Verification before every merge

- `bash -n setup_domoticz.sh`
- `shellcheck setup_domoticz.sh` (zero findings) — install it locally
  (`sudo apt-get install shellcheck`) or rely on the CI workflow
- failure-path test: running without root exits with code 1
- after install-flow changes: test on a real Pi Zero W with Raspberry Pi OS (Legacy, 32-bit) Lite
