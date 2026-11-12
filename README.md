# 🍓 Domoticz ARMv6 Setup Script (Raspberry Pi Zero W)

[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Zero%20W-red.svg)](https://www.raspberrypi.com/)
[![Architecture](https://img.shields.io/badge/Architecture-ARMv6-blue.svg)]()
[![Domoticz](https://img.shields.io/badge/Domoticz-2024.4-green.svg)](https://www.domoticz.com/)

This script automates the installation and configuration of the **Domoticz** home automation server and the **MQTT (Mosquitto)** broker on a Raspberry Pi Zero W (ARMv6 architecture).

### 💡 Why does this script exist?
Official support for **ARMv6** processors (which power the Raspberry Pi Zero W) has been dropped in newer Domoticz versions. A standard installation will fail with an `Illegal instruction` error. This script solves the issue by downloading correctly compiled binaries, installing missing legacy libraries (without breaking the OS), and setting up the service in a modern way using `systemd`.

---

## 🛠️ Prerequisites

Before running the script, ensure that:
1. You have a Raspberry Pi Zero W with a microSD card (min. 16 GB, High Endurance class recommended).
2. You have flashed **Raspberry Pi OS (Legacy, 32-bit) Lite** (preferably using Raspberry Pi Imager v1.8.5 due to known bugs in newer versions).
3. You have configured Wi-Fi, user credentials, and **enabled SSH** during the flashing process.
4. You are logged into the device via terminal (e.g., `ssh admin@ip-address`).

---

## 🚀 Installation

**Step 1: Download the script**
Clone the repository or download the `setup_domoticz.sh` file directly to your Raspberry Pi:

```bash
wget https://raw.githubusercontent.com/kszymczycha/domoticz-pi/main/setup_domoticz.sh
```

**Step 2: Make it executable**
```bash
chmod +x setup_domoticz.sh
```

**Step 3: Run the script as root**
```bash
sudo ./setup_domoticz.sh
```

The script will perform all operations automatically. This process may take 5 to 15 minutes depending on your SD card speed and internet connection.

---

## ⚙️ What does the script do?

1. **Updates the system** to the latest available version.
2. **Installs missing libraries:** `libssl1.1` and `libusb-0.1-4` (temporarily using the Debian Buster repository, which is then safely disabled).
3. **Downloads Domoticz (v2024.4)** along with the web interface files.
4. **Replaces the main binary** with the one prepared by the community (from the `PE1DDA` repository), which is 100% compatible with the ARMv6 processor.
5. **Creates a modern `systemd` service** (replacing the faulty, old `/etc/init.d/` script), ensuring stable background operation and autostart on boot.
6. **Installs and starts the MQTT broker (Mosquitto)**, which is essential for communication with IoT devices (e.g., ESPHome/ESP32).

---

## ⚠️ Important Post-Installation Steps

After the script finishes successfully, open a web browser on your computer and navigate to:
👉 `http://[YOUR_PI_IP_ADDRESS]:8080`

*   **Default login:** `admin`
*   **Default password:** `domoticz`

### 🛑 DO THIS IMMEDIATELY:
1. **Disable automatic updates:** Go to *Setup -> Settings -> System*. In the "Software Updates" section, uncheck the download/update option. **If Domoticz updates to a newer version, it will stop working on the Pi Zero W!**
2. **Change the password:** Go to *Setup -> My Profile* and set a secure password.

---

## 🔍 Troubleshooting

If the web page is not loading or you want to check what is happening in the background, use the following commands:

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

**Check if port 8080 is open:**
```bash
sudo netstat -tulpn | grep 8080
```

---
*Disclaimer: This script is provided as a solution for the ARMv6 support issue. Use at your own risk.*