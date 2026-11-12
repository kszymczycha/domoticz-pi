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

## Suggested order

1. **7** — Mosquitto (code + README MQTT section), so documentation matches behavior
2. **9 + 12** — README only (firewall, Uninstall, Tested on, License)
3. **11** — tag/release once behavior is final
4. **8** — last, separate branch, tested on the device

## Acceptance criteria

- **7 (Mosquitto):** anonymous publish is rejected; publishing with the generated
  credentials succeeds; re-running the installer does not rotate credentials;
  `--mqtt-lan` exposes the broker only with auth; the documented Domoticz setup
  works on a fresh install.
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

- P1.7, P2.11, P2.12: short-lived branch + pull request.
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
