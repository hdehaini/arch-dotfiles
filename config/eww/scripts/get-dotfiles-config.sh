#!/bin/bash

run() {
  if [ -f "$HOME/.config/i3/config-dotfiles" ]; then
    source "$HOME/.config/i3/config-dotfiles"
  else
    MAX_WORKSPACES=5
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    all_ws=$(hyprctl workspaces -j | jq '[.[].id]')
  else
    all_ws=$(i3-msg -t get_workspaces | jq '[.[].num]')
  fi
  echo "$all_ws" | python3 -c "
import json, sys
max_ws = ${MAX_WORKSPACES}
existing = json.loads(sys.stdin.read())
base = list(range(1, max_ws + 1))
extras = sorted(n for n in existing if n > max_ws)
result = base + extras
print(json.dumps(result))
"
}

run

(
  if command -v hyprctl >/dev/null 2>&1; then
    while true; do
      sleep 2
      run
    done
  else
    i3-msg -t subscribe -m '["workspace"]' | while read -r _; do
      run
    done
  fi
) &

(
  inotifywait -m -e moved_to "$HOME/.config/i3/" | while read -r dir event file; do
    if [[ "$file" == "config-dotfiles" ]]; then
      run
    fi
  done
) &

wait
