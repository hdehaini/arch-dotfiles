#!/bin/bash

PANEL=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EWW_CMD=(eww -c "$EWW_CONFIG_DIR")
POPUP_SCRIPT="$EWW_CONFIG_DIR/scripts/popup.sh"

is_open() {
    "${EWW_CMD[@]}" active-windows | grep -Eq "^${1}(:|$)"
}

opening=false
if [[ -n "$PANEL" ]] && ! is_open "$PANEL"; then
    opening=true
fi

# Close panel lain dulu (bukan yang diminta)
[[ "$PANEL" != "wifi_window" ]] && "${EWW_CMD[@]}" active-windows | grep -Eq "^wifi_window(:|$)" && "${EWW_CMD[@]}" close wifi_window 2>/dev/null
[[ "$PANEL" != "bluetooth_window" ]] && "${EWW_CMD[@]}" active-windows | grep -Eq "^bluetooth_window(:|$)" && "${EWW_CMD[@]}" close bluetooth_window 2>/dev/null
[[ "$PANEL" != "audio_window" ]] && "${EWW_CMD[@]}" active-windows | grep -Eq "^audio_window(:|$)" && "${EWW_CMD[@]}" close audio_window 2>/dev/null
[[ "$PANEL" != "control_center_window" ]] && "${EWW_CMD[@]}" active-windows | grep -Eq "^control_center_window(:|$)" && "${EWW_CMD[@]}" close control_center_window 2>/dev/null

# Daemon handling
if [[ "$PANEL" == "wifi_window" ]]; then
    pkill -f wifi_daemon.sh 2>/dev/null
    if $opening; then
        ("${EWW_CMD[@]}" update wifi_networks="$(~/.config/eww//scripts/scan_wifi.sh)" && ~/.config/eww//scripts/wifi_daemon.sh) &
    fi
fi

if [[ "$PANEL" == "bluetooth_window" ]]; then
    pkill -f bluetooth_daemon.sh 2>/dev/null
    if $opening; then
        ~/.config/eww//scripts/bluetooth_daemon.sh &
    fi
fi

# Toggle panel yang diminta (buka kalau tutup, tutup kalau buka)
"$POPUP_SCRIPT" toggle "$PANEL"
