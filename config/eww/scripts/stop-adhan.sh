#!/bin/sh

PID_FILE="/tmp/eww-adhan.pid"

if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
    fi
    rm -f "$PID_FILE"
fi
