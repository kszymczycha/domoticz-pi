# Zigbee2MQTT on the Pi Zero 2 W

Local control of Tuya Zigbee devices, without the Tuya cloud:

```
SONOFF Zigbee/Thread USB Dongle Plus MG24 (Zigbee coordinator)
  -> Zigbee2MQTT (Podman container)
  -> Mosquitto (authentication required)
  -> Domoticz (MQTT Auto Discovery)
```

This is the only supported integration path. Tuya Wi-Fi devices, the Tuya
cloud, a Tuya Zigbee gateway, deCONZ, and Thread/Matter are out of scope.

Target hardware: Raspberry Pi Zero 2 W, 512 MB RAM, Raspberry Pi OS Lite
64-bit (Debian 12 or newer). Zigbee2MQTT 2.x deprecates 32-bit platforms, so
the 64-bit OS is a hard requirement.

---

## 1. Before you start

| Requirement | Why |
| --- | --- |
| Domoticz installed by `setup_domoticz.sh` | Provides the `domoticz` MQTT user |
| Mosquitto with authentication | Anonymous clients are rejected |
| `podman` installed | Zigbee2MQTT runs as a container |
| SONOFF Dongle Plus MG24 flashed with **coordinator firmware 8.0.2** | 8.0.2 is the tested baseline |
| A **USB extension cable** | Hard requirement, see below |

### The USB extension cable is not optional

The MG24 dongle must be physically away from the Pi and its power supply, using
a USB 2.0 extension cable. The Pi's USB ports sit next to the 2.4 GHz Wi-Fi
radio and the switching regulator; both raise the noise floor and cause
intermittent pairing and interview failures that look like software bugs.

Pairing results obtained with the dongle plugged directly into the Pi are
**not accepted**. Do not skip this step, then debug Zigbee2MQTT.

### Install Podman

```bash
sudo apt-get update
sudo apt-get install -y podman
podman --version
```

Quadlet unit files (step 4) need Podman 4.4 or newer. Raspberry Pi OS Trixie
ships a suitable version; on Bookworm (Podman 4.3) use the
`podman generate systemd` fallback described below.

---

## 2. Flash the coordinator firmware

The dongle ships with firmware 7.4.5, which is **not** the tested baseline.

1. Unplug the dongle from the Pi and connect it to your workstation.
2. Open the SONOFF Dongle Flasher (Chrome or Edge, Web Serial):
   <https://dongle.sonoff.tech/sonoff-dongle-flasher/>
3. Select the Dongle Plus MG24 and flash the **Zigbee coordinator** image
   version **8.0.2**.
4. Do not flash router firmware, and do not flash MultiPAN firmware.

Record the exact version in your notes. The flasher is browser-based and does
not publish a checksum, so the version string in the Zigbee2MQTT log is the
only proof of what is running:

```bash
sudo podman logs zigbee2mqtt 2>&1 | grep -iE 'coordinator|firmware|adapter'
```

Expected output mentions the firmware version and `adapter: ember`.

---

## 3. Identify the serial device

Plug the dongle (on the extension cable) into the Pi and find its stable path:

```bash
ls -l /dev/serial/by-id/
```

You will see something like:

```
usb-SONOFF_SONOFF_Dongle_Plus_MG24_0123456789abcdef-if00-port0 -> ../../ttyACM0
```

Use the **`/dev/serial/by-id/...` path** to identify the dongle, never the
`ttyACM` number alone: the number changes on re-enumeration and after a reboot.

Check what it currently resolves to:

```bash
readlink -f /dev/serial/by-id/usb-SONOFF_SONOFF_Dongle_Plus_MG24_*-if00-port0
```

Record both the by-id path and the resolved node. The container is configured
with the resolved node (see section 6), because Podman resolves `--device`
symlinks when the container is created.

---

## 4. Prepare the data directory

```bash
sudo install -d -m 0700 /var/lib/zigbee2mqtt
sudoedit /var/lib/zigbee2mqtt/configuration.yaml
sudo chmod 0600 /var/lib/zigbee2mqtt/configuration.yaml
```

`configuration.yaml`:

```yaml
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://127.0.0.1:1883
  user: domoticz
  password: "<MQTT_PASSWORD>"

serial:
  port: /dev/ttyACM0
  adapter: ember
  baudrate: 115200

frontend:
  enabled: false

homeassistant:
  enabled: true

advanced:
  log_level: info
  pan_id: GENERATE
  ext_pan_id: GENERATE
  network_key: GENERATE
```

Notes:

- `<MQTT_PASSWORD>` is the password printed **once** by `setup_domoticz.sh`.
  This file contains a secret: keep mode `0600`, never commit it.
- `serial.port` is the node **inside the container**, which is the same
  `/dev/ttyACM0` created by `AddDevice` (section 6). Confirm the by-id path
  still points there after every re-plug.
- `adapter: ember` is mandatory. Do **not** use `ezsp`.
- `baudrate: 115200` is the documented value for this dongle.
- `frontend.enabled: false` saves RAM. Pairing and administration are done over
  MQTT (section 7), which is enough for this setup.
- `homeassistant.enabled: true` makes Zigbee2MQTT publish Home Assistant style
  discovery messages under `homeassistant/...`. Domoticz's MQTT Auto Discovery
  gateway consumes exactly those topics. Without it, nothing appears in
  Domoticz.
- `network_key: GENERATE` makes Zigbee2MQTT create the Zigbee network key on
  first start and store it in the data directory. Back that directory up.

---

## 5. Pin the image

Pin both the tag and the digest so an image rebuild cannot silently change your
stack:

```bash
sudo podman pull ghcr.io/koenkk/zigbee2mqtt:2.14.3
sudo podman image inspect --format '{{index .RepoDigests 0}}' \
  ghcr.io/koenkk/zigbee2mqtt:2.14.3
```

The second command prints `ghcr.io/koenkk/zigbee2mqtt@sha256:<digest>`. Use
that full reference in the unit below. When you upgrade, bump the tag **and**
the digest in the same change.

---

## 6. Run it under systemd (Quadlet)

`/etc/containers/systemd/zigbee2mqtt.container`:

```ini
[Unit]
Description=Zigbee2MQTT (SONOFF Dongle Plus MG24)
Wants=network-online.target
After=network-online.target mosquitto.service

[Container]
Image=ghcr.io/koenkk/zigbee2mqtt:2.14.3@sha256:<DIGEST>
ContainerName=zigbee2mqtt
Network=host
Memory=200m
MemorySwap=256m
Volume=/var/lib/zigbee2mqtt:/app/data
AddDevice=/dev/ttyACM0
Environment=TZ=Europe/Warsaw
NoNewPrivileges=true

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

Why these settings:

- `Network=host`: the broker listens on `127.0.0.1:1883`, so the container must
  share the host network namespace. Nothing is published to the LAN.
- `Memory=200m` with `MemorySwap=256m`: a hard cap so a Zigbee2MQTT memory spike
  cannot push the 512 MB board into the OOM killer and take Domoticz with it.
  Raise it to `256m` only if you observe repeated OOM kills.
- `AddDevice=/dev/ttyACM0`: the node Podman creates in the container. Podman
  resolves `--device` symlinks when the container is created, so use the
  resolved node here and restart the service after a re-plug if the dongle
  comes back as `/dev/ttyACM1`.
- Rootful Podman is deliberate: device access is simpler and reproducible than
  rootless with group workarounds.

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now zigbee2mqtt.service
sudo systemctl status zigbee2mqtt.service --no-pager
```

<details>
<summary>Bookworm fallback (Podman 4.3, no Quadlet)</summary>

```bash
sudo podman run -d --name zigbee2mqtt \
  --restart=always \
  --network=host \
  --memory=200m --memory-swap=256m \
  -v /var/lib/zigbee2mqtt:/app/data \
  --device /dev/ttyACM0 \
  -e TZ=Europe/Warsaw \
  ghcr.io/koenkk/zigbee2mqtt:2.14.3@sha256:<DIGEST>

sudo podman generate systemd --new --name zigbee2mqtt \
  | sudo tee /etc/systemd/system/zigbee2mqtt.service
sudo systemctl daemon-reload
sudo systemctl enable --now zigbee2mqtt.service
```

</details>

### First-start checks

```bash
sudo podman logs -f zigbee2mqtt
```

Look for, in order:

1. `Connecting to MQTT server at mqtt://127.0.0.1:1883`
2. `Connected to MQTT server`
3. `Coordinator firmware version: '8.0.2'` (or your recorded version)
4. `Zigbee2MQTT started!`

Any authentication error here means the MQTT user or password is wrong — fix
`configuration.yaml`, then `sudo systemctl restart zigbee2mqtt`.

---

## 7. Pair a device (no frontend)

Pairing is a time-limited window, requested over MQTT. `permit_join` as a
configuration key was removed in Zigbee2MQTT 2.0; the maximum window is 254
seconds.

Terminal A — watch discovery and interviews:

```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'zigbee2mqtt/bridge/logging' -v
```

Terminal B — open a 4-minute window:

```bash
mosquitto_pub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'zigbee2mqtt/bridge/request/permit_join' -m '{"time": 254}'
```

Close it immediately after pairing:

```bash
mosquitto_pub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'zigbee2mqtt/bridge/request/permit_join' -m '{"time": 0}'
```

While the window is open, put the Tuya device into pairing mode (usually a long
press on the button). A successful interview ends with
`device has successfully paired`.

List known devices:

```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'zigbee2mqtt/bridge/devices' -C 1 | python3 -m json.tool | less
```

Rename a device before it reaches Domoticz:

```bash
mosquitto_pub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'zigbee2mqtt/bridge/request/device/rename' \
  -m '{"from": "0x00124b00xxxxxx", "to": "kitchen_plug"}'
```

Naming rule: `room_function`, lowercase, no spaces. Domoticz names are derived
from it, so decide once and stay consistent.

---

## 8. Connect Domoticz

1. *Setup → Hardware → Add*.
2. Type: **MQTT Auto Discovery Client Gateway with LAN interface**.
3. Fill in:
   - *Remote Address*: `127.0.0.1`
   - *Port*: `1883`
   - *Username*: `domoticz`
   - *Password*: the value printed by `setup_domoticz.sh`
   - *MQTT Discovery Prefix*: `homeassistant`
4. Save, wait a minute, then open *Setup → Devices*. Discovered devices arrive
   as unused; add the ones you want.

`MQTT Discovery Prefix` is the exact label in the Domoticz UI; older guides call
it the "auto discovery topic prefix". The value `homeassistant` matches what
Zigbee2MQTT publishes — leave it as the default.

Devices are created when Zigbee2MQTT publishes a discovery config **and** the
first state message arrives. Power-cycle a sensor if it stays hidden.

Verify discovery traffic exists before blaming Domoticz:

```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -u domoticz -P '<MQTT_PASSWORD>' \
  -t 'homeassistant/#' -v -W 15
```

No output means `homeassistant.enabled` is still `false` in
`configuration.yaml`.

---

## 9. Prove it works locally

1. Disconnect the router's WAN/uplink (or block the Pi's internet access).
2. Toggle a device from Domoticz — it must react immediately.
3. Change the state physically (press the button) — Domoticz must follow within
   a few seconds.
4. Reconnect the uplink.

If step 2 or 3 only works with internet access, something is still going
through the Tuya cloud and the setup is wrong.

---

## 10. Operations

### Resources

```bash
sudo podman stats --no-stream zigbee2mqtt
free -m
```

Target: Zigbee2MQTT well under the 200 MB cap, the Pi with at least 80–100 MB
free after a day of uptime. If the container is killed repeatedly
(`dmesg -T | grep -i oom`), raise `Memory=` to `256m` and investigate.

### Backup

```bash
sudo systemctl stop zigbee2mqtt domoticz
sudo tar -C /var/lib -czf ~/zigbee-backup-$(date +%F).tar.gz zigbee2mqtt domoticz/domoticz.db
sudo systemctl start zigbee2mqtt domoticz
```

The Zigbee2MQTT `data/` directory holds the network key and the device
database. Without it, every device must be re-paired. Back it up before any
firmware or image change.

### Upgrade

```bash
sudo podman pull ghcr.io/koenkk/zigbee2mqtt:<NEW_TAG>
sudo podman image inspect --format '{{index .RepoDigests 0}}' \
  ghcr.io/koenkk/zigbee2mqtt:<NEW_TAG>
# update Image= in the Quadlet unit, then:
sudo systemctl daemon-reload
sudo systemctl restart zigbee2mqtt
sudo podman logs --tail 50 zigbee2mqtt
```

Rollback is the same procedure with the previous tag and digest. The data
directory is compatible in both directions for minor upgrades; keep the tar
backup as the real rollback.

### Replace the dongle

The Zigbee network key lives in `data/`. A replacement coordinator restored
back to the **same** firmware version can keep the network; otherwise pair
every device again.

### Uninstall

```bash
sudo systemctl disable --now zigbee2mqtt
sudo rm /etc/containers/systemd/zigbee2mqtt.container
sudo podman rm -f zigbee2mqtt
sudo podman rmi ghcr.io/koenkk/zigbee2mqtt:<TAG>
sudo rm -rf /var/lib/zigbee2mqtt   # deletes the network key
```

Then remove the Domoticz MQTT hardware entry and the discovered devices.

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Error: ... ENOENT` or `permission denied` on the serial path | Device not passed into the container, or the dongle re-enumerated | Check `AddDevice`, then `systemctl restart zigbee2mqtt` |
| `Coordinator firmware ... unsupported` | Old firmware (7.4.5) | Reflash 8.0.2 (section 2) |
| `MQTT error: Connection refused` | Broker down or wrong host | `systemctl status mosquitto`, `ss -ltn | grep 1883` |
| `MQTT error: Not authorized` | Wrong MQTT user/password, or the password file was reset | Re-enter the credentials printed by the installer |
| No devices in Domoticz, but the Z2M log looks fine | `homeassistant.enabled` false, or the wrong AD hardware type | Section 8 and the `homeassistant/#` check |
| Device pairs, then drops off | Weak link or interference | USB extension cable, more routers, change the Zigbee channel |
| Container killed every few hours | Memory cap too low | Raise `Memory=` and check `dmesg` for OOM |

---

## 12. Device Support

Fill this in as devices are verified on real hardware. Until then every row is
a placeholder.

| Device | Model / manufacturer code | In Z2M supported list | Domoticz AD result | Notes |
| --- | --- | --- | --- | --- |
| Tuya smart socket | Placeholder - to be verified | Placeholder - to be verified | Placeholder - to be verified | |
| Tuya relay / switch module | Placeholder - to be verified | Placeholder - to be verified | Placeholder - to be verified | |
| Tuya sensor (temperature/humidity, contact, motion) | Placeholder - to be verified | Placeholder - to be verified | Placeholder - to be verified | |

Rules for this table:

- One row per **model**, not per unit.
- "In Z2M supported list" means the model appears on
  <https://www.zigbee2mqtt.io/supported-devices/> without a custom converter.
- "Domoticz AD result" records whether MQTT Auto Discovery created usable
  devices. A partial result is a real finding, not a failure to hide.
- If a model needs manual topic mapping, note the mapping here instead of
  hardcoding anything in the installer.

---

## 13. Security notes

- `configuration.yaml` contains the MQTT password; `data/database.db` contains
  the Zigbee network key. Both stay on the device, mode `0600`, never in git.
- The container runs rootful. It receives exactly one device node and the host
  network; no extra capabilities are granted.
- The broker refuses anonymous clients. Do not "temporarily" disable
  authentication to debug: add the credentials instead.
- Remote access to Domoticz is a VPN problem, not a port-forwarding problem —
  see [tailscale.md](tailscale.md).
