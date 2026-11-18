# 🍓 Domoticz Setup Script (Raspberry Pi Zero 2 W)

[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Zero%202%20W-red.svg)](https://www.raspberrypi.com/)
[![Architecture](https://img.shields.io/badge/Architecture-aarch64-blue.svg)]()
[![Domoticz](https://img.shields.io/badge/Domoticz-2026.4-green.svg)](https://www.domoticz.com/)
[![ShellCheck](https://github.com/kszymczycha/domoticz-pi/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/kszymczycha/domoticz-pi/actions/workflows/shellcheck.yml)

This script installs and configures the **Domoticz** home automation server and
the **MQTT (Mosquitto)** broker on a Raspberry Pi Zero 2 W running 64-bit
Raspberry Pi OS Lite.

### 💡 Why does this script exist?

Domoticz publishes official builds for `aarch64`, so the Raspberry Pi Zero 2 W
does not need the ARMv6 workarounds used by the previous generation. This script
pins the official release, verifies its SHA256 checksum, installs it under
`/opt`, keeps data in `/var/lib`, and runs it under a dedicated system user with
a hardened `systemd` unit.

---

## 🛠️ Prerequisites

Before running the script, ensure that:

1. You have a **Raspberry Pi Zero 2 W** with a microSD card (min. 16 GB, High
   Endurance class recommended).
2. You have flashed **Raspberry Pi OS Lite 64-bit** (Bookworm or newer; Trixie is
   the current release).
3. You have configured Wi-Fi, user credentials, and **enabled SSH** during the
   flashing process.
4. You are logged into the device via terminal and your user can run `sudo`.

---

## 🚀 Installation

> **Pre-release:** `v2.0.0` has been validated with ShellCheck and checksum
> checks, but not yet on physical hardware. It stays marked as a pre-release on
> GitHub until the hardware test passes.

**Step 1: Download the script and checksums**

```bash
wget https://github.com/kszymczycha/domoticz-pi/releases/download/v2.0.0/setup_domoticz.sh
wget https://github.com/kszymczycha/domoticz-pi/releases/download/v2.0.0/SHA256SUMS
sha256sum -c SHA256SUMS
```

**Step 2: Make it executable**

```bash
chmod +x setup_domoticz.sh
```

**Step 3: Run the script as root**

```bash
sudo ./setup_domoticz.sh
```

Optional flags:

| Flag | Effect |
| --- | --- |
| `--mqtt-lan` | Let the broker listen on `0.0.0.0:1883` (authentication is always on) |
| `--tailscale` | Install Tailscale and enable `tailscaled`; the node is not logged in automatically |
| `-h`, `--help` | Print usage and exit |

An unknown flag exits with code 2. Re-running the installer is safe: it never
overwrites an existing `domoticz.db`, never rotates the MQTT password, and
rewrites the broker configuration from the flags you pass.

The script performs all operations automatically. This may take 10 to 20 minutes
depending on your SD card speed and internet connection.

---

## ⚙️ What does the script do?

1. **Validates the platform:** `aarch64`, Raspberry Pi Zero 2 W, Debian 12+,
   OpenSSL 3+, and at least 512 MB of free space.
2. **Updates the system** and installs runtime dependencies plus Mosquitto.
3. **Downloads Domoticz 2026.4** from the official release and verifies its
   SHA256 checksum.
4. **Installs it under `/opt/domoticz`** as root-owned, read-only application
   files.
5. **Creates a dedicated `domoticz` system user** and keeps the database,
   plugins, scripts, and backups in `/var/lib/domoticz`.
6. **Creates a hardened `systemd` service** with `ProtectSystem=strict`,
   `ProtectHome=true`, `NoNewPrivileges=true`, and a private temporary
   directory.
7. **Configures the MQTT broker (Mosquitto)** with mandatory authentication and
   creates a `domoticz` MQTT user with a generated password, printed once at the
   end. Anonymous clients are rejected.
8. **Verifies the result:** the service is active, the web interface answers on
   port 8080, an anonymous MQTT publish fails, and an authenticated one succeeds.

With `--tailscale` it additionally adds the official Tailscale repository,
installs the package, enables `tailscaled`, and prints the `tailscale up`
command to run. Logging in stays a manual step so the auth key never passes
through the installer.

Application files are never downloaded from a moving URL, and the internal
Domoticz updater is disabled so the pinned version cannot drift.

---

## 📚 Documentation

| Guide | Status | Contents |
| --- | --- | --- |
| [Zigbee2MQTT](docs/zigbee2mqtt.md) | For the next release (`v2.1.0`) | SONOFF Dongle Plus MG24 (firmware 8.0.2, `ember`), Podman container with a 200 MB cap, MQTT Auto Discovery in Domoticz, pairing without the frontend |
| [Tailscale](docs/tailscale.md) | Optional, recommended | Remote access as a VPN instead of port forwarding, ACLs, revocation |

The Zigbee guide assumes this version of the installer (MQTT authentication
included). It is documentation-first: everything runs as documented commands, no
extra logic in `setup_domoticz.sh`.

---

## 🗂️ Layout

| Path | Purpose |
| --- | --- |
| `/opt/domoticz` | binary, web interface, configuration templates |
| `/var/lib/domoticz` | `domoticz.db`, plugins, scripts, backups |
| `/etc/systemd/system/domoticz.service` | service unit |
| `/etc/mosquitto/conf.d/domoticz.conf` | broker authentication and listener |
| `/etc/mosquitto/passwd` | MQTT users (mode `0600`, owner `mosquitto`) |
| `journalctl -u domoticz.service` | logs |

Back up the database with:

```bash
sudo systemctl stop domoticz
sudo cp /var/lib/domoticz/domoticz.db ~/domoticz.db.backup
sudo systemctl start domoticz
```

---

## ⚠️ Important Post-Installation Steps

After the script finishes successfully, open a web browser on your computer and
navigate to:

👉 `http://[YOUR_PI_IP_ADDRESS]:8080`

- **Default login:** `admin`
- **Default password:** `domoticz`

### 🛑 DO THIS IMMEDIATELY:

1. **Change the password:** go to *Setup → My Profile* and set a secure
   password.
2. **Review network exposure:** port 8080 listens on all interfaces. On a
   trusted LAN that is usually acceptable; otherwise restrict it with your
   firewall, for example:
   `sudo ufw allow from <LAN_SUBNET> to any port 8080`.

---

## 🔐 MQTT broker (Mosquitto)

The installer configures the broker for authenticated access only:

- `/etc/mosquitto/conf.d/domoticz.conf` sets `allow_anonymous false` and
  `password_file /etc/mosquitto/passwd`.
- A user `domoticz` is created with a generated password. The password is
  printed **once** at the end of the installation and is never stored in this
  repository.
- By default the broker listens on `127.0.0.1:1883` only.

> ⚠️ **Authentication is always on.** Every client — Domoticz, Zigbee2MQTT, an
> ESP, `mosquitto_pub` — must send the username and password. If you point an
> existing client at this broker without credentials, it will silently fail to
> connect.

### LAN access (`--mqtt-lan`)

Other hosts on the LAN (for example a Zigbee2MQTT instance on a more powerful
machine) need a reachable listener:

```bash
sudo ./setup_domoticz.sh --mqtt-lan
```

This adds `listener 1883 0.0.0.0`, restarts Mosquitto, and prints the matching
firewall rule. Open the firewall yourself and prefer limiting it to the LAN:

```bash
sudo ufw allow from <LAN_SUBNET> to any port 1883
```

Re-running the installer **without** `--mqtt-lan` removes the LAN listener
again. Authentication stays enabled in both cases.

### Add the broker to Domoticz

1. Open *Setup → Hardware*.
2. Add **MQTT Client Gateway with LAN interface** (or **MQTT Auto Discovery
   Client Gateway** for auto-discovery; the Zigbee guide will document which one
   is used).
3. Fill in:
   - *Remote Address:* `127.0.0.1` — or the Pi's LAN address with `--mqtt-lan`
   - *Port:* `1883`
   - *Username:* `domoticz`
   - *Password:* the value printed by the installer
4. Save, then add devices under *Setup → Devices*.

To verify the broker by hand:

```bash
# Must fail: anonymous access is refused.
mosquitto_pub -h 127.0.0.1 -p 1883 -t domoticz/test -m hello

# Must succeed with the printed credentials.
mosquitto_pub -h 127.0.0.1 -p 1883 -u domoticz -P '<password>' -t domoticz/test -m hello
```

### Lost the MQTT password?

The installer never rotates an existing password file. To reset it, remove the
file and run the installer again:

```bash
sudo rm /etc/mosquitto/passwd
sudo ./setup_domoticz.sh
```

Then update the credentials in Domoticz and in every other MQTT client.

---

## 🔄 Moving an existing Domoticz database

The installer never overwrites an existing database. To move data from an old
installation:

```bash
# 1. Run this installer on the new Pi and let it finish.
# 2. Stop the service and keep a copy of the new database.
sudo systemctl stop domoticz
sudo cp /var/lib/domoticz/domoticz.db /var/lib/domoticz/domoticz.db.before-restore

# 3. Copy the old database into place.
sudo cp /path/to/old/domoticz.db /var/lib/domoticz/domoticz.db
sudo chown domoticz:domoticz /var/lib/domoticz/domoticz.db
sudo chmod 0640 /var/lib/domoticz/domoticz.db

# 4. Start Domoticz.
sudo systemctl start domoticz
```

Plugins and scripts live in `/var/lib/domoticz/plugins` and
`/var/lib/domoticz/scripts`; copy them separately if needed.

---

## 🔍 Troubleshooting

**Check service status:**

```bash
sudo systemctl status domoticz.service
```

**View live logs:**

```bash
sudo journalctl -u domoticz.service -f
```

**Restart the service:**

```bash
sudo systemctl restart domoticz.service
```

**Check whether port 8080 is open:**

```bash
ss -ltnp | grep 8080
```

---

## 🧹 Uninstall

```bash
sudo systemctl disable --now domoticz.service
sudo rm /etc/systemd/system/domoticz.service
sudo systemctl daemon-reload
sudo rm -rf /opt/domoticz /var/lib/domoticz
sudo userdel domoticz
sudo apt-get remove --purge mosquitto mosquitto-clients
```

This removes the database as well; back it up first if you need it.

---

## 📄 License

MIT — see [`LICENSE`](LICENSE).

*Disclaimer: This script is provided as-is. Use at your own risk.*