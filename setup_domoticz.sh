#!/bin/bash
#
# Set up Domoticz and Mosquitto on a Raspberry Pi Zero 2 W (aarch64).
# Assumes a freshly installed Raspberry Pi OS Lite 64-bit (Debian 12 or newer)
# with active Wi-Fi connection and SSH access.
#
# All downloaded artifacts are pinned to immutable versions and verified
# against embedded SHA256 checksums before they are used.

set -euo pipefail

trap 'echo "ERROR: setup failed at line $LINENO. See the output above." >&2' ERR

# --- Pinned artifacts -------------------------------------------------------
DOMOTICZ_VERSION="2026.4"
DOMOTICZ_TARBALL_URL="https://github.com/domoticz/domoticz/releases/download/${DOMOTICZ_VERSION}/domoticz_linux_aarch64.tgz"
DOMOTICZ_TARBALL_SHA256="c7bffff723f2b0c81fcebfd803dfb61ebcf6db06442e93ae36085f2e83f25184"

# --- Layout -----------------------------------------------------------------
INSTALL_DIR="/opt/domoticz"
DATA_DIR="/var/lib/domoticz"
SERVICE_USER="domoticz"
HTTP_PORT="8080"

# Minimum free space required on the root filesystem.
MIN_FREE_KB=524288 # 512 MB

TMP_DIR=""
export DEBIAN_FRONTEND=noninteractive

# --- Helpers ----------------------------------------------------------------
cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

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

preflight() {
    [ "${EUID}" -eq 0 ] || die "Run the script with root privileges: sudo ./setup_domoticz.sh"

    local cmd
    for cmd in apt-get awk basename chmod cp curl cut df find getent hostname install \
        mktemp openssl rm sha256sum sleep systemctl tar tr useradd; do
        require_cmd "$cmd"
    done

    [ "$(uname -m)" = "aarch64" ] \
        || die "unsupported architecture: $(uname -m). This installer requires 64-bit Raspberry Pi OS (aarch64)."

    [ -r /proc/device-tree/model ] \
        || die "cannot read /proc/device-tree/model; is this a Raspberry Pi?"

    local model
    model=$(tr -d '\0' < /proc/device-tree/model)
    case "$model" in
        *"Zero 2 W"*) ;;
        *) die "unsupported board: $model. This installer targets the Raspberry Pi Zero 2 W." ;;
    esac

    [ -r /etc/os-release ] || die "cannot read /etc/os-release"

    local os_id os_version
    os_id=$(awk -F= '$1 == "ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
    os_version=$(awk -F= '$1 == "VERSION_ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)

    case "$os_id" in
        debian|raspbian) ;;
        *) die "unsupported OS: $os_id. Use Raspberry Pi OS Lite 64-bit (Debian 12 or newer)." ;;
    esac

    [ -n "$os_version" ] || die "cannot determine the OS version from /etc/os-release"
    [ "${os_version%%.*}" -ge 12 ] \
        || die "Debian 12 (Bookworm) or newer required; found version $os_version."

    local openssl_major
    openssl_major=$(openssl version | awk '{print $2}' | cut -d. -f1)
    [ "$openssl_major" -ge 3 ] \
        || die "OpenSSL 3 or newer required; found $(openssl version)."

    local free_kb
    free_kb=$(df -Pk / | awk 'NR == 2 {print $4}')
    [ "$free_kb" -ge "$MIN_FREE_KB" ] \
        || die "at least 512 MB free space required on /; found $((free_kb / 1024)) MB."
}

install_packages() {
    echo "==> Updating system packages"
    apt-get update
    apt-get -y upgrade

    echo "==> Installing runtime dependencies and Mosquitto"
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libcurl3-gnutls \
        libmosquitto1 \
        libsqlite3-0 \
        libusb-0.1-4 \
        mosquitto \
        mosquitto-clients \
        python3 \
        tar
}

download_domoticz() {
    TMP_DIR=$(mktemp -d)

    echo "==> Downloading Domoticz ${DOMOTICZ_VERSION}"
    curl -fsSL --retry 3 -o "$TMP_DIR/domoticz.tgz" "$DOMOTICZ_TARBALL_URL"

    echo "==> Verifying checksum"
    verify_sha256 "$TMP_DIR/domoticz.tgz" "$DOMOTICZ_TARBALL_SHA256"

    echo "==> Extracting release"
    tar -xzf "$TMP_DIR/domoticz.tgz" -C "$TMP_DIR"
    [ -x "$TMP_DIR/domoticz/domoticz" ] || die "downloaded archive does not contain the domoticz binary"
}

prepare_layout() {
    echo "==> Preparing service account and directories"

    if ! getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
        useradd --system --user-group --home-dir "$DATA_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
    fi

    install -d -m 0755 "$INSTALL_DIR"
    install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "$DATA_DIR"
    install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "$DATA_DIR/plugins" "$DATA_DIR/scripts"

    if systemctl is-active --quiet domoticz.service 2>/dev/null; then
        echo "==> Stopping the running Domoticz service"
        systemctl stop domoticz.service
    fi
}

install_domoticz() {
    echo "==> Installing Domoticz into ${INSTALL_DIR}"
    cp -a "$TMP_DIR/domoticz/." "$INSTALL_DIR/"
    chown -R root:root "$INSTALL_DIR"
    find "$INSTALL_DIR" -type d -exec chmod 0755 {} +
    chmod 0755 "$INSTALL_DIR/domoticz"

    if [ -f "$DATA_DIR/domoticz.db" ]; then
        echo "==> Existing database preserved: $DATA_DIR/domoticz.db"
    fi
}

write_service() {
    local groups=""
    local group

    for group in dialout gpio i2c spi video plugdev input; do
        if getent group "$group" >/dev/null 2>&1; then
            groups="${groups}${groups:+ }${group}"
        fi
    done

    local supplementary=""
    if [ -n "$groups" ]; then
        supplementary="SupplementaryGroups=${groups}"
    fi

    echo "==> Writing the systemd service"
    cat > /etc/systemd/system/domoticz.service <<EOF
[Unit]
Description=Domoticz Home Automation System
Documentation=https://www.domoticz.com/wiki
After=network-online.target time-sync.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
${supplementary}
WorkingDirectory=${DATA_DIR}
ExecStart=${INSTALL_DIR}/domoticz -userdata ${DATA_DIR} -wwwroot ${INSTALL_DIR}/www -www ${HTTP_PORT} -sslwww 0 -wwwbind 0.0.0.0 -noupdates
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
KillMode=process
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
# /sys stays writable so GPIO and USB sysfs devices keep working.
ProtectControlGroups=true
RestrictSUIDSGID=true
ReadWritePaths=${DATA_DIR}
StateDirectory=domoticz
StateDirectoryMode=0750
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 /etc/systemd/system/domoticz.service
    systemctl daemon-reload
    systemctl enable domoticz.service
    systemctl restart domoticz.service
}

setup_mosquitto() {
    echo "==> Enabling Mosquitto"
    systemctl enable --now mosquitto.service
    systemctl is-active --quiet mosquitto.service \
        || die "Mosquitto failed to start; check: systemctl status mosquitto.service"
}

verify_installation() {
    echo "==> Verifying the installation"

    systemctl is-active --quiet domoticz.service || {
        journalctl -u domoticz.service -n 40 --no-pager >&2 || true
        die "Domoticz service is not running"
    }

    local attempt ready=0
    for ((attempt = 1; attempt <= 30; attempt++)); do
        if curl -fsS -o /dev/null "http://127.0.0.1:${HTTP_PORT}/"; then
            ready=1
            break
        fi
        sleep 1
    done

    if [ "$ready" -ne 1 ]; then
        journalctl -u domoticz.service -n 40 --no-pager >&2 || true
        die "Domoticz did not answer on http://127.0.0.1:${HTTP_PORT}/"
    fi

    echo
    echo "Domoticz ${DOMOTICZ_VERSION} is running."
    echo "  Web UI:    http://$(hostname -I | awk '{print $1}'):${HTTP_PORT}"
    echo "  Install:   ${INSTALL_DIR}"
    echo "  Data:      ${DATA_DIR}"
    echo "  Logs:      journalctl -u domoticz.service -f"
    echo
    echo "Mosquitto is active with the default Debian configuration (localhost only)."
    echo "Default Domoticz login: admin / domoticz. Change the password immediately."
}

main() {
    preflight
    install_packages
    download_domoticz
    prepare_layout
    install_domoticz
    write_service
    setup_mosquitto
    verify_installation
}

main "$@"