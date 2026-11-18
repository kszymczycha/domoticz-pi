---
name: domoticz-zero2w
description: Maintain the setup_domoticz.sh installer for Domoticz on Raspberry Pi Zero 2 W (aarch64) - safe edits, artifact bumps, checks, and releases
---

# Domoticz Zero 2 W Installer

Use this skill when changing `setup_domoticz.sh`, bumping the pinned Domoticz
artifacts, updating the README/PLAN, or preparing a release for
`kszymczycha/domoticz-pi`.

## Project facts

- Target: Raspberry Pi Zero 2 W (`aarch64`) running Raspberry Pi OS Lite 64-bit
  (Debian 12 or newer; Trixie is current), OpenSSL 3.
- Domoticz publishes an official `aarch64` build, so no ARMv6 workaround or
  community binary is involved.
- `v1.0.0` is the frozen Raspberry Pi Zero W (ARMv6) reference; it is
  unsupported and must not be modified.
- Layout: read-only application files in `/opt/domoticz`, data in
  `/var/lib/domoticz`, dedicated `domoticz` system user, logs in the journal.
- Everything in the repo is written in English.
- Line endings must stay LF (enforced by `.gitattributes`).
- Roadmap and status live in `PLAN.md`; the script is the source of truth for
  what actually gets installed.
- Device integrations (P3) use one path only: TUYA (Zigbee) devices ->
  Zigbee2MQTT -> Mosquitto -> Domoticz, with the SONOFF Dongle Plus MG24 as
  Zigbee coordinator (firmware 8.0.2, adapter `ember`, never `ezsp`). Tuya
  Wi-Fi, the Tuya cloud/gateway, deCONZ, and Thread/Matter are out of scope.
  Documentation first; no device logic in `setup_domoticz.sh`.
- Domoticz consumes Zigbee2MQTT through native MQTT Auto Discovery; manual topic
  mapping is a per-device fallback, the Python plugin is rejected.
- Zigbee2MQTT runs as a pinned official Podman image (Node.js from the image);
  `frontend: false` by default on the 512 MB board.
- Podman (P4) is rootful and targets the whole chain as the `v3.0.0` layout; the
  native install stays the `v2.x` path. Never run both on one host, never mix the
  two in one script.
- Remote access is Tailscale only (P1.10); no port forwarding, no public
  exposure.
- Mosquitto authentication (P1.7) is a prerequisite: no anonymous broker, not
  even temporarily.

## Invariants

- Keep the eight-step order: preflight validation -> system update and
  dependencies -> download/verify -> service account and directories -> install
  files -> systemd unit -> Mosquitto -> verify. The optional Tailscale step
  (`--tailscale`) runs right after Mosquitto, before verification.
- Never use mutable URLs for artifacts. Pin the release and verify SHA256 before
  installing.
- Never reintroduce: `armv6l`/`armv7l` support, the Buster repository,
  `libssl1.1`, or the community ARMv6 binary swap.
- `/opt/domoticz` stays root-owned and read-only to the service. All runtime
  writes go to `/var/lib/domoticz`.
- Keep the systemd hardening: `NoNewPrivileges`, `PrivateTmp`,
  `ProtectSystem=strict`, `ProtectHome=true`, `ReadWritePaths`, `UMask=0027`.
- Keep `-noupdates`: the pinned release must not drift through the web UI.
- Never host Domoticz binaries in releases (GPLv3 requires offering the source).
- Never overwrite an existing `/var/lib/domoticz/domoticz.db`.
- The script must fail fast and report the failing line.

## Workflow for script changes

1. Read `PLAN.md` and pick an unchecked item.
2. Edit `setup_domoticz.sh`.
3. Run the checks:

   ```bash
   bash -n setup_domoticz.sh
   shellcheck setup_domoticz.sh   # or rely on the CI workflow
   ```

4. Failure-path test: `./setup_domoticz.sh` without root must exit 1 with a
   clear message.
5. Changes that affect the installation flow must be tested on a real Pi Zero 2 W
   before merging. Work goes on `main` for small fixes, or on a `release/vX.Y.Z`
   branch for a release candidate; `feat/zero2w` is merged and must not be reused.
6. Keep `README.md`, `PLAN.md`, `CHANGELOG.md`, and `docs/` in sync in the same
   change; a guide that disagrees with the script is a bug in the guide.

## Bumping Domoticz artifacts

1. Update `DOMOTICZ_VERSION`, `DOMOTICZ_TARBALL_URL`, and
   `DOMOTICZ_TARBALL_SHA256` at the top of `setup_domoticz.sh`.
2. Read the checksum from the published sidecar file:

   ```bash
   curl -sSL -o /tmp/domoticz.tgz "$DOMOTICZ_TARBALL_URL"
   curl -sSL -o /tmp/domoticz.tgz.sha256sum \
     "https://github.com/domoticz/domoticz/releases/download/<version>/domoticz_linux_aarch64.tgz.sha256sum"
   sha256sum /tmp/domoticz.tgz
   cat /tmp/domoticz.tgz.sha256sum
   ```

3. Update the checksum in the same commit.
4. Mention the old and new version in the commit message.

## Release

1. Confirm CI is green and the release was tested on a real Pi Zero 2 W.
2. `git tag -a vX.Y.Z -m "<summary>"` and push the explicit tag ref.
3. Create a GitHub release with `setup_domoticz.sh` and `SHA256SUMS` assets.
   Name the supported board, Domoticz version, OS baseline, and test date in the
   release notes.
4. Point the README download URL at the pinned release asset, not at `main`.

## Git rules

- Short, imperative commit messages in English.
- `v1.0.0` is the frozen Pi Zero W reference. `maint/1.x` is end-of-life: no
  backports, no merges.
- Do not create permanent per-board branches or hardware-suffixed tags. The
  current line supports the Pi Zero 2 W only; dropping it requires a major
  release.
- `main` stays releasable; do not force-push it except for an agreed history
  rewrite.
- Update `PLAN.md` checkboxes when an item is completed.