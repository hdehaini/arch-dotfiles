#!/bin/bash
# Power actions for the bar's control center.
#   power.sh sleep | restart | shutdown | logout
#
# Restart / shut down / log out go through hyprshutdown when it's installed:
# it asks every app to close (so they can save) before the system goes
# down, instead of killing them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/popup.sh" close control_center_window >/dev/null 2>&1

graceful() {   # <label> <command to run after apps close, or empty>
    if command -v hyprshutdown >/dev/null 2>&1; then
        if [ -n "$2" ]; then hyprshutdown -t "$1" -p "$2"; else hyprshutdown -t "$1"; fi
    elif [ -n "$2" ]; then
        $2
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

case "${1:-}" in
    sleep)    systemctl suspend ;;
    restart)  graceful "Restarting..."    "systemctl reboot" ;;
    shutdown) graceful "Shutting down..." "systemctl poweroff" ;;
    logout)   graceful "Logging out..."   "" ;;
    *) echo "usage: power.sh sleep|restart|shutdown|logout" >&2; exit 1 ;;
esac
