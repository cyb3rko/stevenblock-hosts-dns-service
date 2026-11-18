#!/usr/bin/env bash
# Installs the StevenBlack hosts sync service system-wide.
# Run: sudo ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

install -Dm755 stevenblack-hosts-sync.sh /usr/local/bin/stevenblack-hosts-sync.sh
install -Dm644 stevenblack-hosts.service /etc/systemd/system/stevenblack-hosts.service
install -Dm644 stevenblack-hosts.timer /etc/systemd/system/stevenblack-hosts.timer
install -Dm644 local-hosts /etc/stevenblack-hosts/local-hosts

systemctl daemon-reload
systemctl enable --now stevenblack-hosts.timer

echo "Running first sync..."
if systemctl start stevenblack-hosts.service; then
    echo "First sync done. Filter is active until the daily timer updates it."
else
    echo "WARNING: first sync failed, /etc/hosts unchanged. Check:" >&2
    echo "  journalctl -u stevenblack-hosts.service" >&2
fi

echo "Timer status:"
systemctl --no-pager status stevenblack-hosts.timer || true
echo "Local extra entries live in /etc/stevenblack-hosts/local-hosts"
echo "(edit them in this repo and re-run this installer, or edit in place)."
