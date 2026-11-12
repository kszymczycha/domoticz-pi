#!/bin/bash
#
# Script to set up the Domoticz environment for RPi Zero W (ARMv6).
# Assumes a freshly installed Raspberry Pi OS (Legacy, 32-bit) Lite system
# with active Wi-Fi connection and SSH access.
#
# All downloaded artifacts are pinned to immutable versions and verified
# against embedded SHA256 checksums before they are used.

set -euo pipefail

trap 'echo "ERROR: setup failed at line $LINENO. See the output above." >&2' ERR

# --- Pinned artifacts -------------------------------------------------------
DOMOTICZ_VERSION="2024.4"
DOMOTICZ_TARBALL_URL="https://github.com/SjoerdNLD/Domoticz-Armv6/releases/download/${DOMOTICZ_VERSION}/domoticz_linux_${DOMOTICZ_VERSION}_armv6.tgz"
DOMOTICZ_TARBALL_SHA256="f90248a82990f7c403ac6719bae1c670a1a4402a8a43aeb16361171dafd084e3"

# Community compilation for ARMv6, pinned to a commit because "main" moves.
DOMOTICZ_BINARY_COMMIT="b24a421160c101b76bafee4f43b3ee7f60c7468d"
DOMOTICZ_BINARY_URL="https://raw.githubusercontent.com/PE1DDA/Domoticz-ARMv6/${DOMOTICZ_BINARY_COMMIT}/domoticz"
DOMOTICZ_BINARY_SHA256="94489b997c937d401d062e442269612dd65a7b0af2fc2c092598521646933cb6"

# Minimum free space required in the target home directory.
MIN_FREE_KB=524288 # 512 MB

export DEBIAN_FRONTEND=noninteractive

# --- Helpers ----------------------------------------------------------------
verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual

    actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: checksum mismatch for $(basename "$file")" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required command '$1' not found." >&2
        exit 1
    fi
}

is_installed() {
    [ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" = "ii " ]
}

# --- Preconditions ----------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Run the script with root privileges: sudo ./setup_domoticz.sh" >&2
    exit 1
fi

if [ "$(uname -m)" != "armv6l" ]; then
    echo "ERROR: this script targets ARMv6 (armv6l), detected: $(uname -m)" >&2
    exit 1
fi

# Detect the invoking user: the script must be run through sudo from a
# regular account, otherwise there is no sane user to own the installation.
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ] || ! id -u "$SUDO_USER" >/dev/null 2>&1; then
    echo "ERROR: run the script as a regular user with sudo (e.g. sudo ./setup_domoticz.sh)." >&2
    exit 1
fi

TARGET_USER="$SUDO_USER"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

for cmd in wget tar sha256sum systemctl getent; do
    require_cmd "$cmd"
done

FREE_KB=$(df -Pk "$TARGET_HOME" | awk 'NR==2 {print $4}')
if [ "$FREE_KB" -lt "$MIN_FREE_KB" ]; then
    echo "ERROR: not enough free space in $TARGET_HOME (need 512 MB, have $((FREE_KB / 1024)) MB)." >&2
    exit 1
fi

echo "=================================================="
echo " DOMOTICZ INSTALLATION FOR RPI ZERO W"
echo " User: $TARGET_USER"
echo " Home directory: $TARGET_HOME"
echo "=================================================="
sleep 2

# 1. System update
echo "[1/7] Updating system (this may take a few minutes)..."
apt-get update
apt-get full-upgrade -y

# 2. Legacy libraries required by the Domoticz binary
echo "[2/7] Installing legacy libraries (libssl1.1, libusb-0.1-4)..."
if is_installed libssl1.1 && is_installed libusb-0.1-4; then
    echo "      Both libraries are already installed, skipping the Buster repository."
else
    if ! grep -qE '^[^#]*legacy\.raspbian\.org' /etc/apt/sources.list; then
        echo "deb https://legacy.raspbian.org/raspbian/ buster main contrib non-free rpi" >>/etc/apt/sources.list
    fi
    apt-get update
    apt-get install -y libssl1.1 libusb-0.1-4

    # Comment the Buster repository out again to keep future upgrades safe.
    sed -i -E '/^deb .*legacy\.raspbian\.org/s/^/#/' /etc/apt/sources.list
    apt-get update
fi

# 3. Download Domoticz (ARMv6 release with WWW files)
echo "[3/7] Downloading and extracting Domoticz ${DOMOTICZ_VERSION}..."
cd "$TARGET_HOME"
wget -q --show-progress -O domoticz_armv6.tgz "$DOMOTICZ_TARBALL_URL"
verify_sha256 domoticz_armv6.tgz "$DOMOTICZ_TARBALL_SHA256"
tar -xzf domoticz_armv6.tgz
rm -f domoticz_armv6.tgz

# 4. Replace the binary with the PE1DDA compilation
echo "[4/7] Downloading verified ARMv6 binary (PE1DDA, ${DOMOTICZ_BINARY_COMMIT:0:7})..."
rm -f domoticz.new
wget -q --show-progress -O domoticz.new "$DOMOTICZ_BINARY_URL"
verify_sha256 domoticz.new "$DOMOTICZ_BINARY_SHA256"
chmod 0755 domoticz.new
mv -f domoticz.new domoticz

# Set permissions for the user
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/domoticz" "$TARGET_HOME/www"
if [ -d "$TARGET_HOME/plugins" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/plugins"
fi

# 5. Create modern systemd service
echo "[5/7] Configuring systemd service..."
cat <<EOF >/etc/systemd/system/domoticz.service
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
if [ -z "$IP_ADDR" ]; then
    IP_ADDR="<your-pi-ip>"
fi

if systemctl is-active --quiet domoticz.service; then
    echo -e "\n=================================================="
    echo " SUCCESS! Environment has been set up from scratch."
    echo " Domoticz panel: http://$IP_ADDR:8080"
    echo " Default login: admin, password: domoticz"
    echo "=================================================="
    echo " WARNING: After logging into Domoticz for the first time,"
    echo " IMMEDIATELY disable automatic updates in:"
    echo " Setup -> Settings -> System -> Software Updates!"
    printf '==================================================\n\n'
else
    echo -e "\nERROR: Domoticz service did not start correctly." >&2
    printf 'Check logs using: sudo journalctl -u domoticz.service -n 50 --no-pager\n\n' >&2
    exit 1
fi
