#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EWW_CMD=(eww -c "$EWW_CONFIG_DIR")

POPUPS=(
  start_menu
  power_menu
  notification_center
  media_window
  performance_monitor
  control_center_window
  wifi_window
  bluetooth_window
  audio_window
  dotfiles-window
)

is_open() {
  "${EWW_CMD[@]}" active-windows | grep -Eq "^${1}(:|$)"
}

open_window() {
  if ! is_open "$1"; then
    "${EWW_CMD[@]}" open "$1"
  fi
}

close_window() {
  if is_open "$1"; then
    "${EWW_CMD[@]}" close "$1"
  fi
}

set_flags_open() {
  case "$1" in
    start_menu)
      "${EWW_CMD[@]}" update start_menu_visible=true
      ;;
    dotfiles-window)
      "${EWW_CMD[@]}" update dotfiles-window-open=true
      ;;
  esac
}

set_flags_closed() {
  case "$1" in
    start_menu)
      "${EWW_CMD[@]}" update start_menu_visible=false
      ;;
    dotfiles-window)
      "${EWW_CMD[@]}" update dotfiles-window-open=false
      ;;
  esac
}

update_clickaway() {
  for w in "${POPUPS[@]}"; do
    if is_open "$w"; then
      open_window clickaway
      return
    fi
  done
  close_window clickaway
}

cmd="$1"
target="$2"

case "$cmd" in
  open)
    if [[ -z "$target" ]]; then
      echo "Usage: $0 {open|close|toggle|close-all} <window>" >&2
      exit 1
    fi
    open_window clickaway
    open_window "$target"
    set_flags_open "$target"
    update_clickaway
    ;;
  close)
    if [[ -z "$target" ]]; then
      echo "Usage: $0 {open|close|toggle|close-all} <window>" >&2
      exit 1
    fi
    close_window "$target"
    set_flags_closed "$target"
    update_clickaway
    ;;
  toggle)
    if [[ -z "$target" ]]; then
      echo "Usage: $0 {open|close|toggle|close-all} <window>" >&2
      exit 1
    fi
    if is_open "$target"; then
      close_window "$target"
      set_flags_closed "$target"
    else
      open_window clickaway
      open_window "$target"
      set_flags_open "$target"
    fi
    update_clickaway
    ;;
  close-all)
    for w in "${POPUPS[@]}"; do
      close_window "$w"
    done
    set_flags_closed start_menu
    set_flags_closed dotfiles-window
    close_window clickaway
    ;;
  *)
    echo "Usage: $0 {open|close|toggle|close-all} <window>" >&2
    exit 1
    ;;
esac
