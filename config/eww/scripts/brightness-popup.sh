#!/bin/bash

POPUP_NAME="brightness-popup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EWW_CMD=(eww -c "$EWW_CONFIG_DIR")
TIMEOUT=3
PID_FILE="/tmp/eww-brightness-popup.pid"

# Fungsi untuk close popup
close_popup() {
    "${EWW_CMD[@]}" close "$POPUP_NAME" 2>/dev/null
    rm -f "$PID_FILE"
}

# Kill timer lama jika ada
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    kill "$old_pid" 2>/dev/null
fi

# Buka popup jika belum ada
if ! "${EWW_CMD[@]}" active-windows | grep -q "$POPUP_NAME"; then
    "${EWW_CMD[@]}" open "$POPUP_NAME"
fi

# Start timer baru di background
(
    sleep "$TIMEOUT"
    close_popup
) &

# Simpan PID timer baru
echo $! > "$PID_FILE"
