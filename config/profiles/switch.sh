#!/usr/bin/env bash
# Desktop profile switcher.
#
# Usage:
#   switch.sh <profile-name>   activate that profile
#   switch.sh --menu           pick from a wofi menu
#   switch.sh --list           print available profiles
#   switch.sh --current        print active profile
#   switch.sh --new <name>     scaffold a new profile (folder + empty wallpapers/)
#   switch.sh --delete <name>  delete a profile (use --force to skip confirm)
#   switch.sh --rename <old> <new>  rename a profile
#   switch.sh --apply          re-apply the current profile (used at login)
#
# A profile lives at ~/.config/profiles/<name>/ and may contain any of:
#   wallpapers/<monitor>.<ext>  per-output wallpaper (any awww-readable format)
#                               monitor name = output from `hyprctl monitors`
#                               e.g. DP-3.png, HDMI-A-1.jpg
#   colors.scss                 overrides ~/.config/eww/colors.scss
#   apps.json                   overrides ~/.config/eww/apps.json (dock contents)
#
# Anything not provided by the profile falls back to the pristine copy at
# ~/.config/profiles/_defaults/. Add files to _defaults/ to introduce new
# override slots later.

set -u

ROOT="$(readlink -f "$HOME/.config/profiles")"
DEFAULTS="$ROOT/_defaults"
CURRENT_FILE="$ROOT/.current"
EWW_DIR="$HOME/.config/eww"

die()  { notify-send -u critical "Profile switch" "$1"; echo "$1" >&2; exit 1; }
info() { notify-send "Profile" "$1"; }

list_profiles() {
    find "$ROOT" -mindepth 1 -maxdepth 1 -type d \
        ! -name '_defaults' -printf '%f\n' | sort
}

# The active profile; on a fresh install (no .current yet, or it names a
# profile that's gone) the first profile alphabetically.
current_profile() {
    local cur=""
    [ -f "$CURRENT_FILE" ] && cur="$(cat "$CURRENT_FILE")"
    if [ -z "$cur" ] || [ ! -d "$ROOT/$cur" ]; then
        cur="$(list_profiles | head -n1)"
    fi
    echo "${cur:-default}"
}

ensure_awww() {
    command -v awww >/dev/null || die "awww not installed (paru -S awww)"
    if ! pgrep -x awww-daemon >/dev/null; then
        awww-daemon >/dev/null 2>&1 &
        # Wait until the daemon's IPC socket is up.
        local tries=0
        until awww query >/dev/null 2>&1; do
            tries=$((tries + 1))
            [ "$tries" -gt 50 ] && die "awww-daemon failed to start"
            sleep 0.1
        done
    fi
}

apply_wallpapers() {
    local wall_dir="$1/wallpapers"
    local images=() img
    for img in "$wall_dir"/*; do [ -f "$img" ] && images+=("$img"); done
    [ "${#images[@]}" -gt 0 ] || return 0      # nothing to show: keep what's there

    ensure_awww

    # Every connected screen gets wallpapers/<its name>.<ext>. A screen the
    # profile has no file for (another machine, a new monitor) gets the
    # profile's first image instead of staying black.
    local monitors=()
    if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
        mapfile -t monitors < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')
    fi
    if [ "${#monitors[@]}" -eq 0 ]; then       # not in Hyprland: use the file names
        for img in "${images[@]}"; do b="$(basename "$img")"; monitors+=("${b%.*}"); done
    fi

    local monitor match
    for monitor in "${monitors[@]}"; do
        match=""
        for img in "${images[@]}"; do
            b="$(basename "$img")"
            [ "${b%.*}" = "$monitor" ] && { match="$img"; break; }
        done
        [ -n "$match" ] || match="${images[0]}"
        awww img --outputs "$monitor" \
                 --transition-type none \
                 --resize crop \
                 "$(readlink -f "$match")" >/dev/null 2>&1 \
            || echo "warn: could not set wallpaper for $monitor" >&2
    done
}

apply_overrides() {
    local profile_dir="$1"
    for slot in colors.scss apps.json; do
        local src="$profile_dir/$slot"
        local fallback="$DEFAULTS/$slot"
        local dest="$EWW_DIR/$slot"
        if [ -e "$src" ]; then
            cp "$src" "$dest"
        elif [ -e "$fallback" ]; then
            cp "$fallback" "$dest"
        fi
    done
}

reload_eww() {
    eww reload >/dev/null 2>&1 || true
}

activate() {
    local name="$1"
    local profile_dir="$ROOT/$name"
    [ -d "$profile_dir" ] || die "Profile not found: $name"

    apply_wallpapers "$profile_dir"
    apply_overrides "$profile_dir"
    reload_eww

    echo "$name" > "$CURRENT_FILE"
    info "Activated: $name"
}

menu_pick() {
    command -v wofi >/dev/null || die "wofi not installed"
    local choice
    choice="$(list_profiles | wofi --dmenu --prompt "Profile" --width 320 --height 280)"
    [ -n "$choice" ] && activate "$choice"
}

new_profile() {
    local name="$1"
    [ -n "$name" ] || die "Usage: switch.sh --new <name>"
    local profile_dir="$ROOT/$name"
    [ -e "$profile_dir" ] && die "Profile already exists: $name"
    mkdir -p "$profile_dir/wallpapers"
    cat > "$profile_dir/README.txt" <<EOF
Profile: $name

Drop files into this folder to customize:
  wallpapers/<monitor>.<ext>   per-monitor wallpaper (any image awww accepts)
                               monitor names from \`hyprctl monitors\`,
                               e.g. DP-3.png, HDMI-A-1.jpg, HDMI-A-2.png
  colors.scss                  replaces ~/.config/eww/colors.scss
  apps.json                    replaces ~/.config/eww/apps.json (dock)

Anything you do not provide falls back to ~/.config/profiles/_defaults/.

Activate with:   $(basename "$0") $name
Or pick with:    SUPER+SHIFT+P
EOF
    info "Created $name — drop wallpapers into $profile_dir/wallpapers/"
    echo "$profile_dir"
}

delete_profile() {
    local name="$1"
    local force="${2:-}"
    [ -n "$name" ] || die "Usage: switch.sh --delete <name> [--force]"
    [ "$name" = "default" ] && die "Refusing to delete 'default' (it's the fallback)."
    [ "$name" = "_defaults" ] && die "_defaults is not a profile."

    local profile_dir="$ROOT/$name"
    [ -d "$profile_dir" ] || die "Profile not found: $name"

    if [ "$force" != "--force" ]; then
        printf 'Delete profile "%s" (%s)? [y/N] ' "$name" "$profile_dir"
        read -r confirm
        case "$confirm" in
            y|Y|yes|YES) ;;
            *) echo "aborted."; exit 0 ;;
        esac
    fi

    rm -rf -- "$profile_dir"

    # If we just deleted the active profile, fall back to default.
    if [ "$(current_profile)" = "$name" ]; then
        echo "default" > "$CURRENT_FILE"
        activate default
    fi

    info "Deleted profile: $name"
}

rename_profile() {
    local old="$1"
    local new="$2"
    [ -n "$old" ] && [ -n "$new" ] || die "Usage: switch.sh --rename <old> <new>"
    [ "$old" = "default" ]   && die "Refusing to rename 'default' (it's the fallback)."
    [ "$old" = "_defaults" ] && die "_defaults is not a profile."
    [ "$new" = "_defaults" ] && die "'_defaults' is reserved."
    case "$new" in
        */*|-*|"") die "Invalid new name: $new" ;;
    esac

    local old_dir="$ROOT/$old"
    local new_dir="$ROOT/$new"
    [ -d "$old_dir" ] || die "Profile not found: $old"
    [ -e "$new_dir" ] && die "Profile already exists: $new"

    mv -- "$old_dir" "$new_dir"

    # If we just renamed the active profile, point .current at the new name.
    if [ "$(current_profile)" = "$old" ]; then
        echo "$new" > "$CURRENT_FILE"
    fi

    info "Renamed $old → $new"
}

case "${1:-}" in
    "" | -h | --help)
        sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    --list)    list_profiles ;;
    --current) current_profile ;;
    --menu)    menu_pick ;;
    --new)     new_profile "${2:-}" ;;
    --delete)  delete_profile "${2:-}" "${3:-}" ;;
    --rename)  rename_profile "${2:-}" "${3:-}" ;;
    --apply)   activate "$(current_profile)" ;;
    -*)        die "Unknown option: $1" ;;
    *)         activate "$1" ;;
esac
