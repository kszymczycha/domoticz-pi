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
7. **Enables the MQTT broker (Mosquitto)** with the default Debian
   configuration (localhost only).
8. **Verifies the result:** the service is active and the web interface answers
   on port 8080.

Application files are never downloaded from a moving URL, and the internal
Domoticz updater is disabled so the pinned version cannot drift.

---

## 🗂️ Layout

| Path | Purpose |
| --- | --- |
| `/opt/domoticz` | binary, web interface, configuration templates |
| `/var/lib/domoticz` | `domoticz.db`, plugins, scripts, backups |
| `/etc/systemd/system/domoticz.service` | service unit |
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