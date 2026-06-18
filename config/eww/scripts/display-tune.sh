#!/usr/bin/env bash
# Manage software "brightness" (gamma) + night mode (color temp) via
# hyprsunset (Hyprland's CTM protocol). Desktops have no
# /sys/class/backlight, so "brightness" here means gamma — looks the same.
#
# Usage:
#   display-tune.sh brightness=N      set brightness to N (10..100)
#   display-tune.sh night=on|off      force night mode state
#   display-tune.sh night=toggle      flip night mode
#   display-tune.sh                   re-apply current state (e.g. on login)
#
# Multiple args allowed: `display-tune.sh brightness=60 night=on`.
# State persists at /tmp/eww-display (sourced as a bash file).
# Rapid calls (slider drags) are debounced so only the last call respawns
# hyprsunset.

set -u

LOG=/tmp/eww-display.log
{
    echo "----"
    date '+%F %T'
    echo "argv: $*"
} >> "$LOG" 2>&1

STATE_FILE="/tmp/eww-display"
TOKEN_FILE="/tmp/eww-display.token"
DEBOUNCE_MS=180
DEFAULT_BRIGHT=100
DEFAULT_NIGHT=off
NIGHT_TEMP=3400
DAY_TEMP=6500

# --- read current state ---------------------------------------------------
brightness="$DEFAULT_BRIGHT"
night="$DEFAULT_NIGHT"
# shellcheck disable=SC1090
[ -f "$STATE_FILE" ] && . "$STATE_FILE"

# --- apply argv overrides -------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        brightness=*) brightness="${arg#*=}" ;;
        night=on)     night=on ;;
        night=off)    night=off ;;
        night=toggle) [ "$night" = "on" ] && night=off || night=on ;;
        *) echo "warn: unknown arg: $arg" >&2 ;;
    esac
done

case "$brightness" in
    ''|*[!0-9]*) brightness=$DEFAULT_BRIGHT ;;
esac
[ "$brightness" -lt 10  ] && brightness=10
[ "$brightness" -gt 100 ] && brightness=100

# --- persist state IMMEDIATELY (so the eww poll reflects user intent) -----
cat > "$STATE_FILE" <<EOF
brightness=$brightness
night=$night
EOF

# --- debounce: only the last call within DEBOUNCE_MS respawns hyprsunset --
echo $$ > "$TOKEN_FILE"
sleep "$(awk -v m="$DEBOUNCE_MS" 'BEGIN { print m/1000 }')"
[ "$(cat "$TOKEN_FILE" 2>/dev/null)" = "$$" ] || exit 0

# --- compose final hyprsunset args ---------------------------------------
[ "$night" = "on" ] && temp="$NIGHT_TEMP" || temp="$DAY_TEMP"

echo "spawning hyprsunset -t $temp -g $brightness" >> "$LOG"

# hyprsunset is a long-lived process that holds the CTM binding. Kill the
# previous one, then start fresh detached.
pkill -x hyprsunset 2>/dev/null
pkill -x wlsunset   2>/dev/null
sleep 0.2
setsid hyprsunset -t "$temp" -g "$brightness" >/dev/null 2>&1 < /dev/null &
disown 2>/dev/null || true
