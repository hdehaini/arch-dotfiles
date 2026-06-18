#!/bin/bash
ID="$1"
CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww/}"
EWW_CMD=(eww -c "$CONFIG_DIR")
APPS_JSON="$CONFIG_DIR/apps.json"

TMP=$(mktemp)
jq --arg id "$ID" '[.[] | select(.name != $id)]' "$APPS_JSON" > "$TMP" && mv "$TMP" "$APPS_JSON"

BEFORE=$(md5sum "$HOME/.cache/eww-dock.json" | cut -d' ' -f1)

# Tunggu sampai file berubah, max 5 detik
for i in $(seq 1 10); do
  sleep 0.5
  AFTER=$(md5sum "$HOME/.cache/eww-dock.json" | cut -d' ' -f1)
  if [ "$BEFORE" != "$AFTER" ]; then
    break
  fi
done

"${EWW_CMD[@]}" close dock-window && sleep 1.0 && "${EWW_CMD[@]}" open dock-window && "${EWW_CMD[@]}" close dock-window && sleep 1.0 && "${EWW_CMD[@]}" open dock-window
