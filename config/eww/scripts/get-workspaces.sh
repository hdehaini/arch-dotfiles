#!/bin/bash
# Workspace list for the bar, as JSON. Prints once, then again every time
# something changes.
#
# Hyprland: workspaces are per monitor (see hypr/hyprland.lua), each monitor
# owning a block of 10 IDs. For every workspace this prints:
#   id       the real workspace ID (what clicking switches to)
#   num      1..10, the number within its monitor (what the bar shows)
#   monitor  output name
#   group    1, 2, 3... — which monitor, counted left to right (desk row
#            first, screens above/below after); used for colors
#   first    true for the first workspace of a monitor (draws a divider)
#   focused  the workspace you're on
#   visible  showing on some monitor right now

WS_PER_MONITOR=10

hypr_workspaces() {
    local monitors workspaces
    monitors="$(hyprctl monitors -j)" || return
    workspaces="$(hyprctl workspaces -j)" || return
    jq -cn --argjson mons "$monitors" --argjson wss "$workspaces" --argjson per "$WS_PER_MONITOR" '
        # Monitors in bar order: lower rows (the desk) first, then left to right.
        ($mons | sort_by(-.y, .x) | to_entries
               | map({key: .value.name, value: (.key + 1)}) | from_entries) as $group
        | ($mons | map(.activeWorkspace.id)) as $shown
        | ($mons | map(select(.focused)) | .[0].activeWorkspace.id) as $focused
        | $wss
        | map(select(.id > 0))
        | map(. + {group: ($group[.monitor] // 99)})
        | sort_by(.group, .id)
        | map({
              id:      .id,
              num:     (((.id - 1) % $per) + 1),
              monitor: .monitor,
              group:   .group,
              focused: (.id == $focused),
              visible: (.id as $id | $shown | index($id) != null)
          })
        # "first" = first workspace of its monitor group.
        | reduce .[] as $w ({out: [], last: null};
              .out += [$w + {first: ($w.group != .last)}] | .last = $w.group)
        | .out'
}

i3_workspaces() {
    i3-msg -t get_workspaces | jq -c '
        map({
            id: .num, num: .num, monitor: .output, group: 1, first: false,
            focused: .focused, visible: .visible
        }) | sort_by(.id)'
}

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hypr_workspaces
    socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    if command -v socat >/dev/null 2>&1 && [ -S "$socket" ]; then
        # React to Hyprland's events instead of polling.
        socat -U - "UNIX-CONNECT:$socket" | while IFS= read -r event; do
            case "$event" in
                workspace*|focusedmon*|createworkspace*|destroyworkspace*|moveworkspace*|renameworkspace*|monitoradded*|monitorremoved*)
                    hypr_workspaces ;;
            esac
        done
    else
        while sleep 1; do hypr_workspaces; done
    fi
else
    i3_workspaces
    i3-msg -t subscribe -m '["workspace"]' | while read -r _; do
        i3_workspaces
    done
fi
