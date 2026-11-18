# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The public API is the installer CLI, the install layout, and the database
location.

## [2.1.0-rc2] - 2026-11-18

> **RELEASE CANDIDATE — NOT PRODUCTION-READY.**
> Hardware-pending: no row in the "Tested on" table of `README.md` has been
> verified on a physical Raspberry Pi Zero 2 W or a real Zigbee coordinator.
> Static checks pass (ShellCheck, `bash -n`, CLI behaviour) and that is all.
> Supersedes `v2.1.0-rc1`.

### Fixed

- Mosquitto listener verification no longer fails when `ss` lists the IPv6
  loopback first, and it now rejects a non-local listener without `--mqtt-lan`
  (previously it only required `127.0.0.1` to be present, so a wildcard listener
  could slip through).
- MQTT credentials are created before the broker configuration is written, and an
  empty password file aborts with a clear message instead of leaving a broker
  that refuses every client.
- `docs/zigbee2mqtt.md`: replaced the invalid Quadlet `MemorySwap=` key with
  `PodmanArgs=--memory-swap`, and corrected the startup instructions — Quadlet
  units are generated at boot and cannot be `systemctl enable`d.
- README uninstall now removes the Mosquitto configuration, the Tailscale apt
  source and keyring, and the Zigbee2MQTT unit and data; the MQTT hardware
  section states that only one gateway entry should be added.
- Escaped a pipe in the Zigbee troubleshooting table so it renders.
- Documented device removal/re-pair and rejected the Python
  `domoticz-zigbee2mqtt` plugin explicitly.

### Changed

- CI lints `release/**` branches on push, so release candidates are covered
  without a manual `workflow_dispatch`.
- README and `PLAN.md` no longer call `v2.0.0` a stable release; it is still a
  pre-release pending its hardware test.

## [2.1.0-rc1] - 2026-11-18

> **RELEASE CANDIDATE — NOT PRODUCTION-READY.**
> Hardware-pending: no row in the "Tested on" table of `README.md` has been
> verified on a physical Raspberry Pi Zero 2 W or a real Zigbee coordinator.
> Static checks pass (ShellCheck, `bash -n`, CLI behaviour) and that is all.

### Added

- **MQTT authentication is now mandatory.** The installer writes
  `/etc/mosquitto/conf.d/domoticz.conf` with `allow_anonymous false` and a
  password file, creates the `domoticz` user with a generated password
  (`openssl rand -hex 16`), and prints the credentials once. The password is
  hashed via `mosquitto_passwd -U` from a `0600` temporary file, so the plain
  text never appears in a process argument.
- `--mqtt-lan` flag: adds `listener 1883 0.0.0.0`, prints the matching firewall
  rule, and warns when `ufw` is installed but inactive. Re-running without the
  flag removes the listener again.
- `--help` flag and a usage text; an unknown flag exits with code 2.
- `--tailscale` flag: adds the official Tailscale repository for the detected
  Debian codename, installs the package, enables `tailscaled`, and prints the
  tagged `tailscale up` command. The node is never logged in automatically.
- `docs/zigbee2mqtt.md`: the single supported Zigbee path (SONOFF Dongle Plus
  MG24 -> Zigbee2MQTT -> Mosquitto -> Domoticz), with coordinator firmware
  8.0.2, `ember` at 115200, a pinned image, a Quadlet unit with a 200 MB memory
  cap, MQTT-based pairing, MQTT Auto Discovery in Domoticz, backup/upgrade
  procedures, and a "Device Support" table with placeholders.
- `docs/tailscale.md`: why remote access is a VPN and not port forwarding,
  install, tagged auth key, ACL example, `tailscale0` firewall interaction,
  revocation, and uninstall.
- README: "Tested on" table with `PENDING HARDWARE TEST` statuses, "MQTT broker"
  section, documentation index, and a flags table.

### Changed

- README "What does the script do?" now describes authentication, the
  authenticated-publish check, and the optional Tailscale step.
- `PLAN.md`: the roadmap is narrowed to one integration path, records the
  2026-11-18 decisions, and gained an "Open questions" section.

### Security

- Anonymous MQTT clients are rejected; the installer verifies this by attempting
  an anonymous publish and requiring it to fail.
- The broker stays on `127.0.0.1:1883` unless `--mqtt-lan` is passed explicitly.
- Remote access is a VPN (Tailscale); no port forwarding is documented or
  suggested, and TLS on the Pi remains out of scope.

### Upgrade notes

- Upgrading from `v2.0.0` keeps `/var/lib/domoticz/domoticz.db` untouched.
- The first run after the upgrade creates the MQTT password file and prints the
  credentials **once**. Record them: re-running never rotates an existing
  password file.
- Any client that connected to the broker anonymously — Domoticz, an ESP,
  `mosquitto_pub` — must be given the credentials or it will stop working.
- Existing MQTT credentials are preserved; `--mqtt-lan` only changes the
  listener.

### Pending hardware verification

1. Podman/Quadlet support on the target OS (`AddDevice`, `Memory`) and the
   behaviour after a dongle re-plug.
2. Exact Zigbee2MQTT log strings for coordinator firmware and `adapter: ember`.
3. Domoticz MQTT Auto Discovery field names and per-device-type coverage for
   Tuya sockets, relays, and sensors.
4. The MQTT pairing window (`{"time": 254}`) on Zigbee2MQTT 2.14.3.
5. The 200 MB memory cap under pairing load on a 512 MB board.

## [2.0.0] - 2026-11-16

Published as a pre-release; it awaits a hardware test before being promoted.

### Added

- Official Domoticz `aarch64` release, pinned with SHA256 verification.
- `/opt/domoticz` (root-owned, read-only) plus `/var/lib/domoticz` for data.
- Dedicated `domoticz` system user and a hardened systemd unit
  (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `UMask=0027`).
- Platform validation: `aarch64`, Raspberry Pi Zero 2 W, Debian 12+, OpenSSL 3.
- ShellCheck CI workflow.

### Changed

- Dropped Raspberry Pi Zero W (ARMv6) support, the Buster repository, and the
  `libssl1.1` workaround.
- Domoticz logs go to the systemd journal; `-noupdates` disables the internal
  updater.

## [1.0.0] - 2026-11-16

Frozen reference for the Raspberry Pi Zero W (ARMv6). Historical and
unsupported; kept for rolling back the old hardware.

### Added

- Domoticz and Mosquitto installation on Raspberry Pi OS with a community ARMv6
  binary.
- Pinned artifacts with checksum verification and basic systemd hardening.
