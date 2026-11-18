# Shared helpers for the dotfiles CLI commands. Source it, don't run it:
#   . "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
#
# Nothing here is specific to one machine: names, paths and hardware are
# all looked up at run time.

# The CLI is installed as ~/.local/bin/<hostname>; cli exports SELF_NAME.
SELF_NAME="${SELF_NAME:-$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)}"
DOTFILES_DIR="$(readlink -f "$HOME/.config/dotfiles-cli/../..")"

# Colors only when writing to a terminal (NO_COLOR turns them off).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
    C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_CYAN=$'\e[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi

die()     { echo "${C_RED}error:${C_RESET} $*" >&2; exit 1; }
have()    { command -v "$1" >/dev/null 2>&1; }

# Ask a yes/no question; default no. confirm "Delete it?"
confirm() {
    local yn
    printf '%s [y/N] ' "$*"
    read -r yn
    [[ "$yn" =~ ^[Yy] ]]
}

# The installed AUR helper (paru or yay), or nothing.
aur_helper() {
    local h
    for h in paru yay; do have "$h" && { echo "$h"; return; }; done
}

# Bytes → "1.2GB" style.
human() { numfmt --to=iec --suffix=B --format='%.1f' "${1:-0}" 2>/dev/null || echo "${1}B"; }

# Pick a color for a value given warn/crit thresholds (integers).
level_color() {
    local v="${1%.*}" warn="${2%.*}" crit="${3%.*}"
    if   [ "${v:-0}" -ge "$crit" ]; then printf '%s' "$C_RED"
    elif [ "${v:-0}" -ge "$warn" ]; then printf '%s' "$C_YELLOW"
    else printf '%s' "$C_GREEN"; fi
}

# bar <percent> [width] [warn] [crit] → colored "[█████░░░░░]  52%"
bar() {
    local p="${1%.*}" w="${2:-20}" warn="${3:-75}" crit="${4:-90}"
    [ "${p:-0}" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
    local fill=$(( p * w / 100 )) col i out=""
    col="$(level_color "$p" "$warn" "$crit")"
    for (( i = 0; i < w; i++ )); do
        if [ "$i" -lt "$fill" ]; then out+="█"; else out+="░"; fi
    done
    printf '%s%s%s %3d%%' "$col" "$out" "$C_RESET" "$p"
}

# Temperature with color. temp <celsius> [warn] [crit]
temp() {
    [ -n "${1:-}" ] || { printf '%s—%s' "$C_DIM" "$C_RESET"; return; }
    printf '%s%.0f°C%s' "$(level_color "$1" "${2:-70}" "${3:-85}")" "$1" "$C_RESET"
}

# --- hardware sensors, read straight from /sys ----------------------------
# hwmon_dirs <name-regex> → hwmon folders whose driver name matches
hwmon_dirs() {
    local d
    for d in /sys/class/hwmon/hwmon*; do
        grep -qE "^($1)\$" "$d/name" 2>/dev/null && echo "$d"
    done
}

# hwmon_temp_file <hwmon-dir> [label] → path of the matching tempN_input
# (the first one if no label is given)
hwmon_temp_file() {
    local f lbl
    for f in "$1"/temp*_input; do
        [ -r "$f" ] || continue
        if [ -n "${2:-}" ]; then
            lbl="$(cat "${f%_input}_label" 2>/dev/null)"
            [ "$lbl" = "$2" ] || continue
        fi
        echo "$f"; return
    done
}

# read_temp <tempN_input file> → °C with one decimal
read_temp() {
    [ -n "${1:-}" ] && awk '{printf "%.1f", $1 / 1000}' "$1" 2>/dev/null
}

# hwmon_temp <hwmon-dir> [label] → °C
hwmon_temp() { read_temp "$(hwmon_temp_file "$1" "${2:-}")"; }

# temp_limits <tempN_input file> <default-warn> <default-crit> → "warn crit"
# Uses the limits the sensor itself reports when it has them:
#   warn = its "max" (or crit - 15), crit = its "crit" - 5
valid_limit() { [ -n "$1" ] && [ "$1" -gt 20000 ] && [ "$1" -lt 150000 ]; }
temp_limits() {
    local base="${1%_input}" max crit w c
    max="$(cat "${base}_max" 2>/dev/null)"; crit="$(cat "${base}_crit" 2>/dev/null)"
    valid_limit "$max"  || max=""
    valid_limit "$crit" || crit=""
    if [ -n "$crit" ]; then
        c=$(( crit / 1000 - 5 ))
        if [ -n "$max" ] && [ "$max" -lt "$crit" ]; then w=$(( max / 1000 )); else w=$(( crit / 1000 - 15 )); fi
        [ "$c" -le "$w" ] && c=$(( crit / 1000 ))
    elif [ -n "$max" ]; then
        w=$(( max / 1000 - 10 )); c=$(( max / 1000 ))
    else
        w="$2"; c="$3"
    fi
    echo "$w $c"
}

# cpu_temp_file → the CPU's main temperature sensor (AMD, Intel, ARM, ...)
cpu_temp_file() {
    local d f
    d="$(hwmon_dirs 'k10temp|zenpower|coretemp|cpu_thermal|soc_thermal|acpitz' | head -n1)"
    [ -n "$d" ] || return 0
    f="$(hwmon_temp_file "$d" Tctl)"                       # AMD
    [ -n "$f" ] || f="$(hwmon_temp_file "$d" Tdie)"         # older AMD
    [ -n "$f" ] || f="$(hwmon_temp_file "$d" "Package id 0")"  # Intel
    [ -n "$f" ] || f="$(hwmon_temp_file "$d")"
    echo "$f"
}
cpu_temp() { read_temp "$(cpu_temp_file)"; }

# disk_temp_file <disk-name like nvme0n1 / sda> → sensor file or nothing
disk_temp_file() {
    local d
    for d in /sys/block/"$1"/device/hwmon* /sys/block/"$1"/device/hwmon/hwmon*; do
        [ -d "$d" ] && { hwmon_temp_file "$d"; return; }
    done
}

# --- status lines for checks ---------------------------------------------
# Normal mode: every check prints a ✓ / ! / ✗ line under its header.
# Summary mode (SUMMARY=1, used by bare `health`): a category with no
# problems collapses to one "✓ Category" line; otherwise only its
# problems are shown, indented under the category name.
OK_N=0 WARN_N=0 BAD_N=0
SUMMARY=0 SEC="" SEC_OK=0 SEC_SHOWN=0 SEC_BAD=0 SEC_LAST=""

header() {
    if [ "$SUMMARY" = 1 ]; then
        end_section
        SEC="$*" SEC_OK=0 SEC_SHOWN=0 SEC_BAD=0
    else
        printf '\n%s%s%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"
    fi
}

# Summary mode: close the current category (prints its ✓ line if clean).
end_section() {
    [ "$SUMMARY" = 1 ] && [ -n "$SEC" ] || return 0
    if [ "$SEC_SHOWN" = 0 ]; then
        # One check: show what it said. Several: just count them.
        local what=""
        [ "$SEC_OK" -eq 1 ] && what="$SEC_LAST"
        [ "$SEC_OK" -gt 1 ] && what="$SEC_OK checks fine"
        printf '  %s✓%s %-14s %s%s%s\n' "$C_GREEN" "$C_RESET" "$SEC" "$C_DIM" "$what" "$C_RESET"
    fi
    SEC=""
}

# Print the category name before its first problem (summary mode).
_problem_header() {
    [ "$SUMMARY" = 1 ] || return 0
    [ "$SEC_SHOWN" = 0 ] && printf '  %s%s%s\n' "$C_BOLD" "$SEC" "$C_RESET"
    SEC_SHOWN=1
}
_ind() { [ "$SUMMARY" = 1 ] && printf '    ' || printf '  '; }

ok()   { OK_N=$((OK_N + 1)); SEC_OK=$((SEC_OK + 1)); SEC_LAST="$*"
         [ "$SUMMARY" = 1 ] || printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { WARN_N=$((WARN_N + 1)); _problem_header
         printf '%s%s!%s %s\n' "$(_ind)" "$C_YELLOW" "$C_RESET" "$*"; }
bad()  { BAD_N=$((BAD_N + 1)); _problem_header
         printf '%s%s✗%s %s\n' "$(_ind)" "$C_RED" "$C_RESET" "$*"; }
# Hints belong to the problem above them; skip them under a hidden ✓.
hint() { [ "$SUMMARY" = 1 ] && [ "$SEC_SHOWN" = 0 ] && return 0
         printf '%s  %s%s%s\n' "$(_ind)" "$C_DIM" "$*" "$C_RESET"; }

# check_temp_file <name> <tempN_input file> <default-warn> <default-crit>
check_temp_file() {
    [ -n "${2:-}" ] || return 0
    local v w c
    v="$(read_temp "$2")"; [ -n "$v" ] || return 0
    read -r w c < <(temp_limits "$2" "$3" "$4")
    if   [ "${v%.*}" -ge "$c" ]; then bad  "$1 is very hot: $(temp "$v" "$w" "$c")"
    elif [ "${v%.*}" -ge "$w" ]; then warn "$1 is warm: $(temp "$v" "$w" "$c")"
    else ok "$1 $(temp "$v" "$w" "$c")"; fi
}

# show_temp_file <tempN_input file> <default-warn> <default-crit> → colored °C
show_temp_file() {
    local w c
    [ -n "${1:-}" ] || { temp ""; return; }
    read -r w c < <(temp_limits "$1" "$2" "$3")
    temp "$(read_temp "$1")" "$w" "$c"
}
