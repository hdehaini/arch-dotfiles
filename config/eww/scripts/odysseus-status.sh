#!/usr/bin/env bash
# Prints "on" if the odysseus container is running, "off" otherwise.
# Used by the dashboard toggle poll.

state=$(docker inspect -f '{{.State.Running}}' odysseus-odysseus-1 2>/dev/null)

if [ "$state" = "true" ]; then
    echo "on"
else
    echo "off"
fi
