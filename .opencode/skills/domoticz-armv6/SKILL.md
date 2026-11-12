---
name: Domoticz ARMv6 Installer
description: Maintain the setup_domoticz.sh installer for Domoticz on Raspberry Pi Zero W (ARMv6) - safe edits, artifact bumps, checks, and releases
---

# Domoticz ARMv6 Installer

Use this skill when changing `setup_domoticz.sh`, bumping the pinned Domoticz
artifacts, updating the README/PLAN, or preparing a release for
`kszymczycha/domoticz-pi`.

## Project facts

- Target: Raspberry Pi Zero W (ARMv6 / `armv6l`) running Raspberry Pi OS
  (Legacy, 32-bit) Lite.
- Upstream Domoticz dropped ARMv6, so the script swaps in a community build.
- Everything in the repo is written in English.
- Line endings must stay LF (enforced by `.gitattributes`).
- Roadmap and status live in `PLAN.md`; the script is the source of truth for
  what actually gets installed.

## Invariants

- Keep the seven-step order: system update -> legacy libs -> extract release ->
  swap binary -> systemd -> Mosquitto -> verify.
- Never use mutable URLs for artifacts. Pin releases and commits, and verify
  SHA256 before installing.
- Never host Domoticz binaries in releases (GPLv3 requires offering the source).
- Never reintroduce an `admin` fallback user.
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
5. Changes that affect the installation flow must be tested on a real Pi Zero W
   before merging; use branch `refactor/layout` for P1.8.

## Bumping Domoticz artifacts

1. Update the version/URL constants at the top of `setup_domoticz.sh`.
2. Recompute the checksums:

   ```bash
   curl -sSL -o /tmp/domoticz.tgz "$DOMOTICZ_TARBALL_URL"
   curl -sSL -o /tmp/domoticz.bin "$DOMOTICZ_BINARY_URL"
   sha256sum /tmp/domoticz.tgz /tmp/domoticz.bin
   ```

3. Update both SHA256 constants in the same commit.
4. Mention the old and new version in the commit message.

## Release

1. Confirm CI is green on `main`.
2. `git tag -a vX.Y.Z -m "<summary>"` and push the tag.
3. Create a GitHub release with `setup_domoticz.sh` and `SHA256SUMS` assets.
4. Point the README download URL at the release, not at `main`.

## Git rules

- Short, imperative commit messages in English.
- `main` stays releasable; do not force-push it except for an agreed history
  rewrite.
- Update `PLAN.md` checkboxes when an item is completed.
