#!/bin/bash

count=0
paused=false

if command -v dunstctl >/dev/null 2>&1; then
    count="$(dunstctl count waiting 2>/dev/null || echo 0)"
    paused="$(dunstctl is-paused 2>/dev/null || echo false)"
fi

if [[ -z "$count" ]]; then count=0; fi
icon="󰂚"
class="normal"

if [[ "$paused" == "true" ]]; then
    icon="󰪑"
    class="paused"
elif [[ "$count" != "0" ]]; then
    icon="󰵙"
    class="has-alerts"
fi

printf '{"text":"%s  %s","tooltip":"Pending notifications: %s\\nLeft click: popup\\nRight click: history/center","class":"%s"}\n' "$icon" "$count" "$count" "$class"
