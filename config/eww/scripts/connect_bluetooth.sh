#!/bin/bash

MAC="$1"
ACTION="${2:-toggle}"
EWW_CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww/}"
EWW_CMD=(eww -c "$EWW_CONFIG_DIR")

if ! command -v bluetoothctl >/dev/null 2>&1; then
    notify-send "Bluetooth" "bluetoothctl not installed"
    exit 0
fi

if [ -z "$MAC" ]; then
    exit 1
fi

case "$ACTION" in
    connect)
        bluetoothctl connect "$MAC"
        ;;
    disconnect)
        bluetoothctl disconnect "$MAC"
        ;;
    toggle)
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            bluetoothctl disconnect "$MAC"
        else
            # Pair dulu jika belum paired
            if ! bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
                bluetoothctl pair "$MAC"
                sleep 2
            fi
            bluetoothctl connect "$MAC"
        fi
        ;;
    pair)
        bluetoothctl pair "$MAC"
        ;;
    unpair)
        bluetoothctl remove "$MAC"
        ;;
esac

# Refresh list setelah action
sleep 1
"${EWW_CMD[@]}" update bluetooth_devices_listen="$(~/.config/eww//scripts/scan_bluetooth.sh)"
