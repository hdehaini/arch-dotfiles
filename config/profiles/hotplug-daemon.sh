#!/usr/bin/env bash
# Listens to Hyprland's event socket and re-applies the active profile
# whenever a monitor is connected (TV turning on, dock plugged in, etc.).
#
# Started by `exec-once` in hyprland.conf. Safe to run a second copy;
# the first thing it does is kill any other instance of itself.

set -u

LOG="/tmp/profiles-hotplug.log"
SOCKET="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
SWITCH="$HOME/.config/profiles/switch.sh"

# Single-instance: kill any older copy of this script.
pkill -f "$(basename "$0")" --older 1 2>/dev/null

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

[ -S "$SOCKET" ] || { log "Hyprland socket not found at $SOCKET"; exit 1; }
[ -x "$SWITCH" ] || { log "switch.sh not executable"; exit 1; }

# Debounce: many monitor events fire back-to-back when a display wakes
# (monitoraddedv2 + monitoradded + workspace + focusedmon). Coalesce them
# into one --apply call per quiet window.
trigger() {
    [ -n "${PENDING_PID:-}" ] && kill "$PENDING_PID" 2>/dev/null
    ( sleep 0.6
      log "running switch.sh --apply"
      "$SWITCH" --apply >> "$LOG" 2>&1
    ) &
    PENDING_PID=$!
}

log "hotplug daemon up (socket=$SOCKET)"
socat -U - "UNIX-CONNECT:$SOCKET" 2>>"$LOG" | while IFS= read -r line; do
    case "$line" in
        monitoraddedv2*|monitoradded*)
            log "event: $line"
            trigger
            ;;
    esac
done
