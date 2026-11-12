#!/bin/bash

# Script to set up the Domoticz environment for RPi Zero W (ARMv6)
# Assumes a freshly installed Raspberry Pi OS (Legacy, 32-bit) Lite system
# with active Wi-Fi connection and SSH access.

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Run the script with root privileges: sudo ./setup_domoticz.sh"
  exit 1
fi

# Detect user (if script is run with sudo)
TARGET_USER=${SUDO_USER:-admin}
TARGET_HOME=$(eval echo ~$TARGET_USER)

echo "=================================================="
echo " DOMOTICZ INSTALLATION FOR RPI ZERO W"
echo " User: $TARGET_USER"
echo " Home directory: $TARGET_HOME"
echo "=================================================="
sleep 2

# 1. System update
echo "[1/7] Updating system (this may take a few minutes)..."
apt-get update && apt-get full-upgrade -y

# 2. Add Buster repository for libssl1.1
echo "[2/7] Configuring repository for libssl1.1..."
if ! grep -q "legacy.raspbian.org" /etc/apt/sources.list; then
    echo "deb https://legacy.raspbian.org/raspbian/ buster main contrib non-free rpi" >> /etc/apt/sources.list
fi
apt-get update
apt-get install -y libssl1.1 libusb-0.1-4

# Disable Buster repository to prevent errors in future updates
sed -i 's/^deb https:\/\/legacy.raspbian.org\/raspbian\/ buster/#deb https:\/\/legacy.raspbian.org\/raspbian\/ buster/' /etc/apt/sources.list
apt-get update

# 3. Download Domoticz (ARMv6 version with WWW files)
echo "[3/7] Downloading and extracting Domoticz..."
cd "$TARGET_HOME" || exit
wget -q --show-progress -O domoticz_armv6.tgz https://github.com/SjoerdNLD/Domoticz-Armv6/releases/download/2024.4/domoticz_linux_2024.4_armv6.tgz
tar -xzvf domoticz_armv6.tgz
rm domoticz_armv6.tgz

# 4. Replace binary with PE1DDA compilation
echo "[4/7] Downloading fixed binary (PE1DDA)..."
wget -q --show-progress -O domoticz https://raw.githubusercontent.com/PE1DDA/Domoticz-ARMv6/main/domoticz
chmod +x domoticz

# Set permissions for the user
chown -R $TARGET_USER:$TARGET_USER "$TARGET_HOME/domoticz" "$TARGET_HOME/www" 2>/dev/null || true
if [ -d "$TARGET_HOME/plugins" ]; then
    chown -R $TARGET_USER:$TARGET_USER "$TARGET_HOME/plugins"
fi

# 5. Create modern systemd service
echo "[5/7] Configuring systemd service..."
cat <<EOF > /etc/systemd/system/domoticz.service
[Unit]
Description=Domoticz Home Automation System
After=network.target

[Service]
Type=simple
User=$TARGET_USER
WorkingDirectory=$TARGET_HOME
ExecStart=$TARGET_HOME/domoticz -www 8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Remove old, faulty init.d script (if exists)
rm -f /etc/init.d/domoticz.sh

# Start service
systemctl daemon-reload
systemctl enable domoticz.service
systemctl start domoticz.service

# 6. Install MQTT broker (Mosquitto)
echo "[6/7] Installing MQTT broker (Mosquitto)..."
apt-get install -y mosquitto mosquitto-clients
systemctl enable mosquitto
systemctl start mosquitto

# 7. Verification and summary
echo "[7/7] Verification..."
sleep 3
IP_ADDR=$(hostname -I | awk '{print $1}')

if systemctl is-active --quiet domoticz.service; then
    echo -e "\n=================================================="
    echo " SUCCESS! Environment has been set up from scratch."
    echo " Domoticz panel: http://$IP_ADDR:8080"
    echo " Default login: admin, password: domoticz"
    echo "=================================================="
    echo " WARNING: After logging into Domoticz for the first time,"
    echo " IMMEDIATELY disable automatic updates in:"
    echo " Setup -> Settings -> System -> Software Updates!"
    echo "==================================================\n"
else
    echo -e "\nERROR: Domoticz service did not start correctly."
    echo "Check logs using: sudo journalctl -u domoticz.service -n 50 --no-pager\n"
fi