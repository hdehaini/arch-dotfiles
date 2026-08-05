#!/bin/bash

if ! command -v bluetoothctl >/dev/null 2>&1; then
    notify-send "Bluetooth" "bluetoothctl not installed"
    exit 0
fi

# Cek status bluetooth saat ini
STATUS=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [ "$STATUS" = "yes" ]; then
    # Matikan bluetooth
    bluetoothctl power off
else
    # Nyalakan bluetooth
    bluetoothctl power on
fi
