#!/bin/bash

cpu="$(awk -v RS='' '{printf "%d", ($2+$4)*100/($2+$4+$5)}' /proc/stat 2>/dev/null)"
mem="$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}' 2>/dev/null)"

if [[ -z "$cpu" ]]; then cpu=0; fi
if [[ -z "$mem" ]]; then mem=0; fi

class="normal"
if (( cpu > 85 || mem > 90 )); then
    class="critical"
elif (( cpu > 70 || mem > 75 )); then
    class="warning"
fi

printf '{"text":"󰍹  %s%%/%s%%","tooltip":"CPU: %s%%\\nRAM: %s%%","class":"%s"}\n' "$cpu" "$mem" "$cpu" "$mem" "$class"
