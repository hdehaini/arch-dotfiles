#!/usr/bin/env bash
# Copy a single image into a profile's wallpapers/ folder, targeting a
# specific monitor. Pair with split-wallpaper.sh when you want two
# pre-split images already on disk instead of slicing a wide one.
#
# Usage:
#   set-wallpaper.sh [flags] <image> <profile> <monitor>
#
# Flags:
#   --apply           switch.sh <profile> after writing
#   --colors          also generate colors.scss from <image> via matugen
#   --prefer <kind>   matugen --prefer value (default: darkness)
#
# Examples:
#   set-wallpaper.sh ~/Pictures/left.png  work DP-3
#   set-wallpaper.sh ~/Pictures/right.png work HDMI-A-2
#   set-wallpaper.sh ~/Pictures/tv.png    work HDMI-A-1
#
#   # Set the TV wallpaper, palette the eww bar after it, and activate:
#   set-wallpaper.sh --colors --apply ~/Pictures/tv.png work HDMI-A-1
#
# Monitor names come from `hyprctl monitors`. Any existing wallpaper for
# the same monitor (whatever extension) is replaced.

set -eu

die() { echo "error: $*" >&2; exit 1; }

GEN_COLORS=0
DO_APPLY=0
PREFER=darkness

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

[ $# -eq 3 ] || die "usage: $(basename "$0") [--apply] [--colors] <image> <profile> <monitor>"

IMG="$1"
PROFILE="$2"
MONITOR="$3"

[ -f "$IMG" ] || die "image not found: $IMG"

PROFILE_DIR="$HOME/.config/profiles/$PROFILE"
[ -d "$PROFILE_DIR" ] || die "profile not found: $PROFILE (create it with switch.sh --new $PROFILE)"

WALL_DIR="$PROFILE_DIR/wallpapers"
mkdir -p "$WALL_DIR"

# Drop any prior file for this monitor (any extension) so the switcher
# doesn't see two and pick the alphabetically-last one.
rm -f -- "$WALL_DIR/$MONITOR".*

# Keep the source extension. swww reads everything common.
EXT="${IMG##*.}"
DEST="$WALL_DIR/$MONITOR.$EXT"
cp -- "$IMG" "$DEST"

echo "wallpaper:"
echo "  $DEST"

# --- optional: generate colors.scss via matugen ---------------------------
if [ "$GEN_COLORS" -eq 1 ]; then
    command -v matugen >/dev/null || die "matugen not installed (pacman -S matugen)"

    TEMPLATE="$HOME/.config/matugen/templates/eww-colors.scss"
    [ -f "$TEMPLATE" ] || die "missing template: $TEMPLATE"

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

if [ "$DO_APPLY" -eq 1 ]; then
    echo
    "$HOME/.config/profiles/switch.sh" "$PROFILE"
else
    echo
    echo "activate with:  ~/.config/profiles/switch.sh $PROFILE"
fi
