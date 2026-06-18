#!/usr/bin/env bash
# Thin wrapper kept for back-compat with any other binding.
# Real work happens in display-tune.sh so brightness and night mode share
# one wlsunset process.
exec "$(dirname "$0")/display-tune.sh" night=toggle
