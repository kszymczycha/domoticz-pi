# Domoticz Zero 2 W Installer

`setup_domoticz.sh` installs Domoticz and Mosquitto on a Raspberry Pi Zero 2 W
running Raspberry Pi OS Lite 64-bit (aarch64, Debian 12 or newer).

## Start here

- Read `PLAN.md` for the roadmap, acceptance criteria, and recorded decisions.
- Load the `domoticz-zero2w` skill for the maintenance procedure, invariants,
  checks, and release steps.
- Take the first unchecked item in the suggested order unless told otherwise.

## Non-negotiables

- Repository content is in English and line endings stay LF.
- Do not push or force-push `main` unless the user explicitly asks.
- Keep `main` releasable.
- `v1.0.0` is the frozen Raspberry Pi Zero W (ARMv6) reference; the current
  line targets the Raspberry Pi Zero 2 W only.