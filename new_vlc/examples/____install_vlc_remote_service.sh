#!/bin/bash
# Idempotent script to install and configure VLC Remote Service as a systemd service.
# Can be run multiple times safely. Will always (re)configure and (re)start the service.

SERVICE_NAME="vlc-remote"
SCRIPT_PATH="/home/pda/vlc_tv/start_cvlc_remote.sh"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Script not found: $SCRIPT_PATH"
  exit 1
fi

echo "Writing systemd unit file: $UNIT_FILE"
cat > "$UNIT_FILE" <<EOF
[Unit]
Description=VLC Remote Control Service
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=on-failure
User=pda

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$UNIT_FILE"

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling service to start at boot..."
systemctl enable "$SERVICE_NAME"

echo "Restarting (or starting) the service..."
systemctl restart "$SERVICE_NAME"

echo "Systemd service '${SERVICE_NAME}' is configured and running."
echo "To check status: sudo systemctl status ${SERVICE_NAME}"
echo "To view logs: sudo journalctl -u ${SERVICE_NAME} -e"
