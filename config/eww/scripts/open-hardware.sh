#!/usr/bin/env bash
# Bar's hardware stats → the dashboard on its Performance tab. Clicking again
# while that's showing closes it.
DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
EWW=(eww -c "$DIR")
if "${EWW[@]}" active-windows | grep -q '^performance_monitor' &&
   [ "$("${EWW[@]}" get active_tab)" = performance ]; then
    exec "$DIR/scripts/popup.sh" close performance_monitor
fi
"${EWW[@]}" update active_tab=performance
exec "$DIR/scripts/popup.sh" open performance_monitor
