# Domoticz Zero 2 W Installer

`setup_domoticz.sh` installs Domoticz and Mosquitto on a Raspberry Pi Zero 2 W
running Raspberry Pi OS Lite 64-bit (aarch64, Debian 12 or newer).

## Start here

- Read `PLAN.md` for the roadmap, acceptance criteria, recorded decisions, and
  the current "Next action" (development is paused until the Pi Zero 2 W and the
  MG24 dongle arrive).
- Load the `domoticz-zero2w` skill for the maintenance procedure, invariants,
  checks, and release steps.
- Deployment guides: `docs/zigbee2mqtt.md` and `docs/tailscale.md`. Release
  history: `CHANGELOG.md`. Hardware status: the "Tested on" table in `README.md`.
- Take the first unchecked item in the suggested order unless told otherwise,
  skipping anything that needs the physical board or the Zigbee coordinator.

## Non-negotiables

- Repository content is in English and line endings stay LF.
- Do not push or force-push `main` unless the user explicitly asks.
- Keep `main` releasable.
- `v1.0.0` is the frozen Raspberry Pi Zero W (ARMv6) reference; the current
  line targets the Raspberry Pi Zero 2 W only.
- A published release-candidate tag is never moved: cut the next RC instead.
- Keep `README.md`, `PLAN.md`, `CHANGELOG.md`, and `docs/` in sync in the same
  change.
