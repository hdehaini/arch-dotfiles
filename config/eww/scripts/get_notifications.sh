#!/bin/bash
# Emit dunst's notification history as JSON for eww.
#
# Dunst stores timestamps as microseconds since the *monotonic boot clock*,
# not unix epoch — earlier versions of this script tried to treat them as
# epoch nanoseconds and everything came out as 00:00. Convert by adding
# the boot-time epoch.

MODE="${1:-all}"
RECENT_COUNT=10

# Boot time in unix epoch seconds = now - uptime.
BOOT_EPOCH=$(awk -v now="$(date +%s)" '{printf "%d", now - $1}' /proc/uptime)

output=$(dunstctl history 2>/dev/null | jq -c \
    --arg mode "$MODE" \
    --argjson n "$RECENT_COUNT" \
    --argjson boot "$BOOT_EPOCH" '
  [.data[0][]? | {
    appname: .appname.data,
    summary: .summary.data,
    body: .body.data,
    id: .id.data,
    icon: .icon_path.data,
    time: ((.timestamp.data / 1000000 + $boot) | strflocaltime("%-I:%M %p"))
  }] |
  if   $mode == "recent"  then .[:$n]
  elif $mode == "earlier" then .[$n:]
  else . end
' 2>/dev/null)

if [[ -z "$output" || "$output" == "null" ]]; then
    echo '[]'
else
    echo "$output"
fi
