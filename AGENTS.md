# Domoticz ARMv6 Installer

`setup_domoticz.sh` installs Domoticz and Mosquitto on a Raspberry Pi Zero W
(ARMv6 / `armv6l`) running Raspberry Pi OS (Legacy, 32-bit) Lite, using a
community-built Domoticz binary because upstream dropped ARMv6 support.

## Before starting

- Read `PLAN.md` for the roadmap, acceptance criteria, and open decisions.
- Load the `domoticz-armv6` skill for the maintenance procedure.
- Work on the first unchecked item in the suggested order unless told otherwise.

## Conventions

- All repository content (code, comments, docs, commit messages) is in English.
- Line endings must stay LF (enforced by `.gitattributes`).
- Pin artifacts to immutable versions and verify SHA256 before use; never use
  mutable URLs.
- Never host Domoticz binaries in releases (GPLv3 source obligation).
- The script must fail fast and report the failing line.

## Checks before committing

```bash
bash -n setup_domoticz.sh
shellcheck setup_domoticz.sh   # or rely on the CI workflow
```

Changes that affect the installation flow require testing on a real Pi Zero W
before merging.

## Git

- Short, imperative commit messages.
- Keep `main` releasable.
- Do not push or force-push `main` unless the user explicitly asks.
