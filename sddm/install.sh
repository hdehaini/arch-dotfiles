#!/usr/bin/env bash
# Install (or refresh) the arch-dotfiles login screen for SDDM.
#
# Usage:
#   sddm/install.sh                 build from the active profile and install
#   sddm/install.sh <image>         same, with a specific background picture
#   sddm/install.sh --preview [img] show it in a window instead (no install,
#                                   no sudo; close the window to finish)
#
# The theme takes its colors from the active profile's colors.scss and,
# unless you pass an image, its background from that profile's wallpaper
# for the first monitor. SDDM can't read your home folder, so the picture
# is copied into the theme. Re-run this after switching profiles if you
# want the login screen to follow (or: <hostname> profile login-screen).

set -eu

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SRC="$REPO/sddm/arch-dotfiles"
NAME="arch-dotfiles"
DEST="/usr/share/sddm/themes/$NAME"
CONF="/etc/sddm.conf.d/10-$NAME.conf"
PROFILES="$HOME/.config/profiles"

die() { echo "error: $*" >&2; exit 1; }

PREVIEW=0 IMAGE=""
for a in "$@"; do
    case "$a" in
        --preview)  PREVIEW=1 ;;
        -h|--help)  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)         die "unknown flag: $a" ;;
        *)          IMAGE="$a" ;;
    esac
done
[ "$(id -u)" -ne 0 ] || die "run this as your normal user (it asks for sudo when needed)"
[ -f "$SRC/Main.qml" ] || die "theme files missing: $SRC"

# --- pick a background ----------------------------------------------------
if [ -z "$IMAGE" ]; then
    profile="$("$PROFILES/switch.sh" --current 2>/dev/null)"
    walls="$PROFILES/$profile/wallpapers"
    # Prefer the first monitor's picture; otherwise any picture in the profile.
    first=""
    if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        first="$(hyprctl monitors -j | jq -r 'sort_by(.id) | .[0].name // empty')"
    fi
    [ -n "$first" ] && IMAGE="$(ls "$walls/$first".* 2>/dev/null | head -n1 || true)"
    [ -n "$IMAGE" ] || IMAGE="$(ls "$walls"/* 2>/dev/null | head -n1 || true)"
fi
[ -z "$IMAGE" ] || [ -f "$IMAGE" ] || die "image not found: $IMAGE"

# --- colors from the active palette ---------------------------------------
colors="$HOME/.config/eww/colors.scss"
color() {   # color <scss variable> <fallback>
    local v
    v="$(sed -n "s/^\$$1: *\(#[0-9a-fA-F]\{6\}\);.*/\1/p" "$colors" 2>/dev/null | head -n1)"
    echo "${v:-$2}"
}

# --- build the theme in a temp folder -------------------------------------
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
cp -r "$SRC/." "$build/"

background=""
if [ -n "$IMAGE" ]; then
    # Scale down and save as JPEG: smaller, and the greeter blurs it anyway.
    if command -v magick >/dev/null; then
        magick "$IMAGE[0]" -resize '2560x1440>' -quality 90 "$build/background.jpg"
    else
        cp "$IMAGE" "$build/background.${IMAGE##*.}"
    fi
    background="$(cd "$build" && ls background.* | head -n1)"
fi

cat > "$build/theme.conf" <<EOF
[General]
# Written by sddm/install.sh from the "$(cat "$PROFILES/.current" 2>/dev/null || echo default)" profile.
background=$background
accent=$(color primary "#c7bfff")
onAccent=$(color on-primary "#2f295f")
surface=$(color surface "#131318")
text=$(color on-surface "#e5e1e9")
error=$(color error "#ffb4ab")
font=Inter
clock24=false
EOF

if [ "$PREVIEW" = 1 ]; then
    greeter="$(command -v sddm-greeter-qt6 || command -v sddm-greeter || true)"
    [ -n "$greeter" ] || die "sddm-greeter not found (is sddm installed?)"
    echo "previewing — close the window to finish (logging in and power buttons do nothing here)"
    "$greeter" --test-mode --theme "$build"
    exit 0
fi

# --- install ----------------------------------------------------------------
echo "installing the login screen (needs sudo)..."
sudo rm -rf "$DEST"
sudo mkdir -p "$DEST"
sudo cp -r "$build/." "$DEST/"
sudo chmod -R a+rX "$DEST"

sudo mkdir -p /etc/sddm.conf.d
sudo tee "$CONF" >/dev/null <<EOF
# Written by arch-dotfiles/sddm/install.sh
[Theme]
Current=$NAME
CursorTheme=Windows-10
CursorSize=22
EOF

echo "done: $DEST"
echo "      $CONF"
echo "you'll see it the next time you log out or restart."
