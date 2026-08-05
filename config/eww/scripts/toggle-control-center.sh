#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EWW_CMD=(eww -c "$EWW_CONFIG_DIR")
POPUP_SCRIPT="$EWW_CONFIG_DIR/scripts/popup.sh"

"${EWW_CMD[@]}" active-windows | grep -Eq "^wifi_window(:|$)" && "${EWW_CMD[@]}" close wifi_window 2>/dev/null
"${EWW_CMD[@]}" active-windows | grep -Eq "^bluetooth_window(:|$)" && "${EWW_CMD[@]}" close bluetooth_window 2>/dev/null
"${EWW_CMD[@]}" active-windows | grep -Eq "^audio_window(:|$)" && "${EWW_CMD[@]}" close audio_window 2>/dev/null
"$POPUP_SCRIPT" toggle control_center_window
