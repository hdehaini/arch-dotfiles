#!/usr/bin/env bash
# Slice one wide image into per-monitor halves for the desk monitors
# and drop them into a profile's wallpapers/ folder.
#
# Usage:
#   split-wallpaper.sh [flags] <image> <profile> [left-monitor] [right-monitor]
#
# Flags (any order, before or after positional args):
#   --colors          generate colors.scss from the wallpaper via matugen
#                     and write it to <profile>/colors.scss
#   --apply           switch.sh <profile> after writing files
#   --prefer <kind>   matugen --prefer value when picking a source color
#                     (default: darkness; others: lightness, saturation,
#                     less-saturation, value, closest-to-fallback)
#
# Defaults: left=DP-3, right=HDMI-A-2.
#
# Examples:
#   split-wallpaper.sh ~/Pictures/wide.png work
#   split-wallpaper.sh --colors --apply wide.png work
#   split-wallpaper.sh --colors --prefer saturation wide.jpg chill HDMI-A-2 DP-3

set -eu

die() { echo "error: $*" >&2; exit 1; }

GEN_COLORS=0
DO_APPLY=0
PREFER=darkness

# Parse flags without touching positional args order.
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --colors)  GEN_COLORS=1; shift ;;
        --apply)   DO_APPLY=1;   shift ;;
        --prefer)  PREFER="$2";  shift 2 ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)        die "unknown flag: $1" ;;
        *)         POSITIONAL+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL[@]}"

[ $# -ge 2 ] || die "usage: $(basename "$0") [--colors] [--apply] <image> <profile> [left] [right]"
command -v magick >/dev/null || die "ImageMagick not found (pacman -S imagemagick)"

IMG="$1"
PROFILE="$2"
LEFT_MON="${3:-DP-3}"
RIGHT_MON="${4:-HDMI-A-2}"

[ -f "$IMG" ] || die "image not found: $IMG"

PROFILE_DIR="$HOME/.config/profiles/$PROFILE"
[ -d "$PROFILE_DIR" ] || die "profile not found: $PROFILE (create it with switch.sh --new $PROFILE)"

WALL_DIR="$PROFILE_DIR/wallpapers"
mkdir -p "$WALL_DIR"

# --- split into halves ----------------------------------------------------
read -r WIDTH HEIGHT < <(magick identify -format '%w %h\n' "$IMG")
HALF=$(( WIDTH / 2 ))
[ "$HALF" -gt 0 ] || die "image has zero width"

if [ "$WIDTH" -lt $(( HEIGHT * 2 )) ]; then
    echo "warn: $IMG is ${WIDTH}x${HEIGHT} — narrower than 2:1, each half"
    echo "      will look squished on a 16:9 monitor." >&2
fi

LEFT_OUT="$WALL_DIR/${LEFT_MON}.png"
RIGHT_OUT="$WALL_DIR/${RIGHT_MON}.png"

magick "$IMG" -crop "${HALF}x${HEIGHT}+0+0"        +repage "$LEFT_OUT"
magick "$IMG" -crop "${HALF}x${HEIGHT}+${HALF}+0"  +repage "$RIGHT_OUT"

echo "wallpapers:"
echo "  $LEFT_OUT  (${HALF}x${HEIGHT})"
echo "  $RIGHT_OUT (${HALF}x${HEIGHT})"

# --- optional: generate colors.scss via matugen ---------------------------
if [ "$GEN_COLORS" -eq 1 ]; then
    command -v matugen >/dev/null || die "matugen not installed (pacman -S matugen)"

    TEMPLATE="$HOME/.config/matugen/templates/eww-colors.scss"
    [ -f "$TEMPLATE" ] || die "missing template: $TEMPLATE"

    # Build a one-shot matugen config that writes the SCSS into this profile.
    TMP_CONFIG="$(mktemp --suffix=.toml)"
    trap 'rm -f "$TMP_CONFIG"' EXIT
    cat > "$TMP_CONFIG" <<EOF
[config]
type = "standard"

[templates.eww-colors]
input_path = '$TEMPLATE'
output_path = '$PROFILE_DIR/colors.scss'
EOF

    matugen -q -c "$TMP_CONFIG" --prefer "$PREFER" image "$IMG"

    echo "colors:"
    echo "  $PROFILE_DIR/colors.scss  (matugen --prefer $PREFER)"
fi

# --- optional: activate the profile ---------------------------------------
if [ "$DO_APPLY" -eq 1 ]; then
    echo
    "$HOME/.config/profiles/switch.sh" "$PROFILE"
else
    echo
    echo "activate with:  ~/.config/profiles/switch.sh $PROFILE"
fi
