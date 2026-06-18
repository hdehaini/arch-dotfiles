#!/bin/bash

# Fungsi untuk get workspace state
get_workspaces() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl workspaces -j | jq -c '
            map(select(.id > 0) | {
                num: .id,
                name: (.name // (.id | tostring)),
                focused: (.focused // false),
                urgent: false,
                visible: (.visible // false),
                output: (.monitor // "")
            }) | sort_by(.num)'
    else
        i3-msg -t get_workspaces | jq -c '
            map({
                num: .num,
                name: .name,
                focused: .focused,
                urgent: .urgent,
                visible: .visible,
                output: .output
            }) | sort_by(.num)'
    fi
}

# Output initial state
get_workspaces

if command -v hyprctl >/dev/null 2>&1; then
    while true; do
        sleep 1
        get_workspaces
    done
else
    i3-msg -t subscribe -m '["workspace"]' | while read -r line; do
        get_workspaces
    done
fi
