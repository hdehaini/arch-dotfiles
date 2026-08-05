#!/bin/bash
# Simpan sebagai ~/.config/eww//scripts/i3-mode.sh

if command -v hyprctl >/dev/null 2>&1; then
    echo "default"
    while true; do
        sleep 3600
    done
else
    i3-msg -t subscribe -m '["mode"]' | while read -r line; do
        # Parse JSON untuk mendapatkan nama mode
        mode=$(echo "$line" | jq -r '.change')
        
        # Output mode name (akan dibaca oleh eww sebagai deflisten)
        echo "$mode"
    done
fi
