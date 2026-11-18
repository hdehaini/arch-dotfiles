#!/usr/bin/env bash
# Put wallpapers into a profile, on whichever screens you want.
# Normally run as `<hostname> profile wallpaper ...`; see --help.
# Screens come from Hyprland at run time, so this works with any monitors.

set -eu

PROFILES="$HOME/.config/profiles"
CMD="${SELF_NAME:-$(hostname -s 2>/dev/null || uname -n)} profile wallpaper"
die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warn: $*" >&2; }

show_help() {
    cat <<EOF
$CMD — put wallpapers into a profile, on whichever screens you want.

Usage: $CMD [action] [args] [flags]

Actions:
  show [profile]                    What a profile puts on each screen and
                                    what each screen shows now (the default)
  screens                           Connected screens and their short names
  set <image> <profile> <screen>... The same image on every screen listed
  split <image> <profile> [screen...]
                                    Cut one wide image into side-by-side
                                    pieces, one per screen, left to right in
                                    the order listed (default: the desk row)

Screens: output names (see "screens") or short names worked out from your
Hyprland layout, whatever monitors you have:
  left, right       the ends of the desk row (the row with the most screens)
  center            the middle one, when the desk row has an odd number
  1 2 3 ...         desk screens counted from the left
  top / tv          the screen(s) above the desk row
  desk              the whole desk row
  all               every connected screen

<profile> can be "." for the active profile.

Flags:
  --apply           Activate the profile after writing the files
  --colors          Make <profile>/colors.scss from the image (matugen)
  --prefer <kind>   matugen --prefer hint (default: darkness)

Examples:
  $CMD split ultrawide.png work                 across the whole desk row
  $CMD split wide.png work left center          only across these two
  $CMD set   tv.png work top                    just the screen above
  $CMD set   pic.png . all --apply              everywhere, active profile
EOF
}

# --- screen layout --------------------------------------------------------
# One line per connected screen: "name x y logical_width logical_height".
# Logical size = pixel size / scale, swapped if the screen is rotated.
LAYOUT=""
load_layout() {
    [ -n "$LAYOUT" ] && return 0
    command -v hyprctl >/dev/null || die "hyprctl not found (are you in Hyprland?)"
    command -v jq      >/dev/null || die "jq not found (pacman -S jq)"
    LAYOUT="$(hyprctl monitors -j | jq -r '.[] | select(.disabled | not) |
        (if (.transform % 2) == 1 then [.height, .width] else [.width, .height] end) as $s |
        "\(.name) \(.x) \(.y) \($s[0] / .scale | floor) \($s[1] / .scale | floor)"')"
    [ -n "$LAYOUT" ] || die "no screens found from hyprctl"
}

# The desk row is the row (same y) with the most screens; ties go to the
# lower row. Everything above it counts as "top".
desk_row() {
    load_layout
    local y
    y="$(awk '{c[$3]++} END {for (y in c) print c[y], y}' <<<"$LAYOUT" \
         | sort -k1,1nr -k2,2nr | head -n1 | cut -d' ' -f2)"
    awk -v y="$y" '$3 == y' <<<"$LAYOUT" | sort -k2,2n | cut -d' ' -f1
}
top_row() {
    load_layout
    local y
    y="$(awk -v n="$(desk_row | head -n1)" '$1 == n {print $3}' <<<"$LAYOUT")"
    awk -v y="$y" '$3 < y' <<<"$LAYOUT" | sort -k3,3n -k2,2n | cut -d' ' -f1
}

# Turn one screen argument into one or more output names.
resolve() {
    local arg="$1" desk n
    mapfile -t desk < <(desk_row); n=${#desk[@]}
    case "$arg" in
        all)    load_layout; sort -k3,3n -k2,2n <<<"$LAYOUT" | cut -d' ' -f1; return ;;
        desk)   desk_row; return ;;
        tv|top) top_row | grep . || die "no screen above the desk row"; return ;;
        left)   [ "$n" -ge 2 ] || die "'left' needs at least 2 desk screens (found $n)"
                echo "${desk[0]}"; return ;;
        right)  [ "$n" -ge 2 ] || die "'right' needs at least 2 desk screens (found $n)"
                echo "${desk[-1]}"; return ;;
        center|centre|middle)
                [ $(( n % 2 )) -eq 1 ] && [ "$n" -ge 3 ] || die "'center' needs an odd number of desk screens (found $n)"
                echo "${desk[$(( n / 2 ))]}"; return ;;
        [1-9]|[1-9][0-9])
                [ "$arg" -le "$n" ] || die "there are only $n desk screens"
                echo "${desk[$(( arg - 1 ))]}"; return ;;
    esac
    # A raw output name. Allow disconnected ones, but say so.
    load_layout
    awk -v n="$arg" '$1 == n {f=1} END {exit !f}' <<<"$LAYOUT" \
        || warn "$arg is not connected right now (writing it anyway)"
    echo "$arg"
}

resolve_all() {
    local a
    for a in "$@"; do resolve "$a"; done
}

# Short names for an output ("left, 1"), or nothing.
alias_of() {
    local name="$1" d n i names=()
    if top_row | grep -qx "$name"; then echo "top"; return; fi
    mapfile -t d < <(desk_row); n=${#d[@]}
    for (( i = 0; i < n; i++ )); do
        [ "${d[$i]}" = "$name" ] || continue
        [ "$n" -ge 2 ] && [ "$i" -eq 0 ] && names+=(left)
        [ "$n" -ge 3 ] && [ $(( n % 2 )) -eq 1 ] && [ "$i" -eq $(( n / 2 )) ] && names+=(center)
        [ "$n" -ge 2 ] && [ "$i" -eq $(( n - 1 )) ] && names+=(right)
        [ "$n" -ge 2 ] && names+=("$((i + 1))")
    done
    local IFS=,; echo "${names[*]}" | sed 's/,/, /g'
}

show_screens() {
    load_layout
    local name x y w h
    printf '%-10s %-11s %-14s %s\n' OUTPUT SIZE POSITION "SHORT NAME"
    sort -k3,3n -k2,2n <<<"$LAYOUT" | while read -r name x y w h; do
        printf '%-10s %-11s %-14s %s\n' "$name" "${w}x${h}" "$x,$y" "$(alias_of "$name")"
    done
}

# What each screen gets from a profile, and what it's showing right now.
do_show() {
    [ $# -le 1 ] || die "usage: $CMD show [profile]"
    local dir prof name f now shown=" "
    dir="$(profile_dir "${1:-.}")"; prof="$(basename "$dir")"
    load_layout
    local active; active="$(cat "$PROFILES/.current" 2>/dev/null)"
    echo "profile: $prof$([ "$prof" = "$active" ] && echo "  (active)")"
    echo
    printf '%-10s %-12s %-28s %s\n' SCREEN "SHORT NAME" "IN PROFILE" "ON SCREEN NOW"
    # Current image per output, from the wallpaper daemon.
    local query=""
    command -v awww >/dev/null && query="$(awww query 2>/dev/null || true)"
    while read -r name _; do
        f="$(cd "$dir/wallpapers" 2>/dev/null && ls "$name".* 2>/dev/null | head -n1)"
        now="$(awk -v n="$name" -F'currently displaying: ' '$0 ~ ": "n":" {print $2}' <<<"$query")"
        case "$now" in
            image:*) now="$(basename "${now#image: }")"
                     # Say which profile it's from if it's not this one.
                     local from; from="$(awk -v n="$name" -F'image: ' '$0 ~ ": "n":" {print $2}' <<<"$query")"
                     from="$(basename "$(dirname "$(dirname "$from")")")"
                     [ "$from" != "$prof" ] && now="$now  (from \"$from\")" ;;
            color:*) now="plain color #${now#color: }" ;;
            "")      now="?" ;;
        esac
        printf '%-10s %-12s %-28s %s\n' "$name" "$(alias_of "$name")" "${f:-(none)}" "$now"
        shown+="$name "
    done < <(sort -k3,3n -k2,2n <<<"$LAYOUT")

    # Files for screens that aren't connected right now.
    for f in "$dir"/wallpapers/*; do
        [ -e "$f" ] || continue
        name="$(basename "${f%.*}")"
        [[ "$shown" == *" $name "* ]] && continue
        printf '%-10s %-12s %-28s %s\n' "$name" "" "$(basename "$f")" "(not connected)"
    done
}

# --- shared steps ---------------------------------------------------------
profile_dir() {
    local p="$1"
    if [ "$p" = "." ]; then
        [ -f "$PROFILES/.current" ] || die "no active profile yet"
        p="$(cat "$PROFILES/.current")"
    fi
    [ -d "$PROFILES/$p" ] || die "profile not found: $p (create it with: ${CMD% wallpaper} new $p)"
    echo "$PROFILES/$p"
}

make_colors() {
    local img="$1" dir="$2"
    command -v matugen >/dev/null || die "matugen not installed (pacman -S matugen)"
    local template="$HOME/.config/matugen/templates/eww-colors.scss"
    [ -f "$template" ] || die "missing template: $template"
    local cfg
    cfg="$(mktemp --suffix=.toml)"
    cat > "$cfg" <<EOF
[config]
type = "standard"

[templates.eww-colors]
input_path = '$template'
output_path = '$dir/colors.scss'
EOF
    matugen -q -c "$cfg" --prefer "$PREFER" image "$img" || { rm -f "$cfg"; die "matugen failed"; }
    rm -f "$cfg"
    echo "colors:"
    echo "  $dir/colors.scss  (matugen --prefer $PREFER)"
}

finish() {
    local img="$1" dir="$2"
    [ "$GEN_COLORS" -eq 1 ] && make_colors "$img" "$dir"
    echo
    if [ "$DO_APPLY" -eq 1 ]; then
        "$PROFILES/switch.sh" "$(basename "$dir")"
    else
        echo "activate with:  ${CMD% wallpaper} switch \"$(basename "$dir")\"  (or add --apply)"
    fi
}

# --- actions --------------------------------------------------------------
do_set() {
    [ $# -ge 3 ] || die "usage: $CMD set <image> <profile> <screen>...  (screen names: $CMD screens)"
    local img="$1" dir; dir="$(profile_dir "$2")"; shift 2
    [ -f "$img" ] || die "image not found: $img"
    mkdir -p "$dir/wallpapers"

    local ext="${img##*.}" mon mons
    mons="$(resolve_all "$@")" || exit 1        # stop on a bad screen name
    echo "wallpapers:"
    for mon in $(awk '!seen[$0]++' <<<"$mons"); do
        # Remove an old file for this screen (any extension) so the
        # switcher doesn't find two.
        rm -f -- "$dir/wallpapers/$mon".*
        cp -- "$img" "$dir/wallpapers/$mon.$ext"
        echo "  $dir/wallpapers/$mon.$ext"
    done
    finish "$img" "$dir"
}

do_split() {
    [ $# -ge 2 ] || die "usage: $CMD split <image> <profile> [screen...]  (screen names: $CMD screens)"
    command -v magick >/dev/null || die "ImageMagick not found (pacman -S imagemagick)"
    local img="$1" dir; dir="$(profile_dir "$2")"; shift 2
    [ -f "$img" ] || die "image not found: $img"
    [ $# -gt 0 ] || set -- desk

    local mons resolved
    resolved="$(resolve_all "$@")" || exit 1    # stop on a bad screen name
    mapfile -t mons < <(awk '!seen[$0]++' <<<"$resolved")
    [ "${#mons[@]}" -ge 2 ] || die "split needs at least 2 screens (use 'set' for one)"

    # Each piece gets a width share matching its screen. Screens that are
    # not connected count as 1920x1080.
    load_layout
    local widths=() total=0 tallest=0 m w h
    for m in "${mons[@]}"; do
        w=""; h=""
        read -r w h < <(awk -v n="$m" '$1 == n {print $4, $5}' <<<"$LAYOUT") || true
        w="${w:-1920}"; h="${h:-1080}"
        widths+=("$w"); total=$(( total + w ))
        [ "$h" -gt "$tallest" ] && tallest="$h"
    done

    # Crop the image (centered) to the combined shape of the screens, so
    # the pieces line up with each other instead of being cropped one by one.
    local iw ih cw ch
    read -r iw ih < <(magick identify -format '%w %h\n' "$img[0]")
    if [ $(( iw * tallest )) -gt $(( ih * total )) ]; then
        ch=$ih; cw=$(( ih * total / tallest ))
    else
        cw=$iw; ch=$(( iw * tallest / total ))
    fi
    if [ $(( ih * total )) -gt $(( iw * tallest * 3 / 2 )) ]; then
        warn "image is ${iw}x${ih}, much narrower than the ${#mons[@]} screens"
        warn "(${total}x${tallest}); a lot of the top and bottom will be cut off."
    fi

    local tmp; tmp="$(mktemp --suffix=.png)"
    magick "$img[0]" -gravity center -crop "${cw}x${ch}+0+0" +repage "$tmp"

    mkdir -p "$dir/wallpapers"
    echo "wallpapers:"
    local x=0 i pw out
    for i in "${!mons[@]}"; do
        m="${mons[$i]}"
        # The last piece takes whatever is left so no pixels are lost.
        if [ "$i" -eq $(( ${#mons[@]} - 1 )) ]; then
            pw=$(( cw - x ))
        else
            pw=$(( cw * widths[i] / total ))
        fi
        rm -f -- "$dir/wallpapers/$m".*
        out="$dir/wallpapers/$m.png"
        magick "$tmp" -crop "${pw}x${ch}+${x}+0" +repage "$out"
        echo "  $out  (${pw}x${ch})"
        x=$(( x + pw ))
    done
    rm -f "$tmp"
    finish "$img" "$dir"
}

# --- main -----------------------------------------------------------------
GEN_COLORS=0
DO_APPLY=0
PREFER=darkness

action="${1:-show}"
[ $# -gt 0 ] && shift
case "$action" in
    -h | --help | help) show_help; exit 0 ;;
esac

ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --colors)  GEN_COLORS=1; shift ;;
        --apply)   DO_APPLY=1;   shift ;;
        --prefer)  [ $# -ge 2 ] || die "--prefer needs a value"; PREFER="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        -*)        die "unknown flag: $1" ;;
        *)         ARGS+=("$1"); shift ;;
    esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

case "$action" in
    screens|monitors) show_screens ;;
    show)             do_show "$@" ;;
    set)              do_set "$@" ;;
    split)            do_split "$@" ;;
    *) die "unknown action: $action (try: $CMD --help)" ;;
esac
