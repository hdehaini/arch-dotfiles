#!/usr/bin/env bash
# Toggles the odysseus selfhost stack. Brings it up if any container is
# missing or stopped, otherwise tears it down. The dashboard polls
# odysseus-status.sh on a 5s interval to reflect the new state.

set -u

COMPOSE_DIR="/mnt/storage/selfhost/odysseus"

state=$(docker inspect -f '{{.State.Running}}' odysseus-odysseus-1 2>/dev/null)

cd "$COMPOSE_DIR" || {
    notify-send "Odysseus" "Compose dir not found: $COMPOSE_DIR"
    exit 1
}

if [ "$state" = "true" ]; then
    notify-send "Odysseus" "Stopping containers..."
    docker compose down >/tmp/odysseus-toggle.log 2>&1 &&
        notify-send "Odysseus" "Stopped" ||
        notify-send "Odysseus" "Stop failed — see /tmp/odysseus-toggle.log"
else
    notify-send "Odysseus" "Starting containers..."
    docker compose up -d >/tmp/odysseus-toggle.log 2>&1 &&
        notify-send "Odysseus" "Started" ||
        notify-send "Odysseus" "Start failed — see /tmp/odysseus-toggle.log"
fi
