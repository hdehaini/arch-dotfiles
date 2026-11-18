#!/usr/bin/env bash
# Old name, kept so existing commands still work. See wallpaper.sh.
exec "$(dirname "$(readlink -f "$0")")/wallpaper.sh" split "$@"
