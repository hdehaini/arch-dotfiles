# health software — desktop, services, processes, logs, packages.
# Sourced by commands/health.
#   software_show [section...]   detailed view
#   software_check               quick ✓ / ! / ✗ lines for `health`

SOFTWARE_SECTIONS="desktop services processes logs packages"

PROFILES="$HOME/.config/profiles"

# command:package:required(1)/optional(0):what it's for
TOOLS=(
    "hyprctl:hyprland:1:the compositor"
    "awww:awww:1:wallpapers"
    "eww:eww-git:1:the bar"
    "wofi:wofi:1:menus"
    "jq:jq:1:reading Hyprland's monitor info"
    "magick:imagemagick:1:splitting wallpapers"
    "matugen:matugen:1:colors from wallpapers"
    "notify-send:libnotify:1:notifications"
    "socat:socat:1:monitor hotplug watcher"
    "lspci:pciutils:1:GPU names"
    "paccache:pacman-contrib:0:cleaning the package cache"
    "nmcli:networkmanager:0:Wi-Fi details in health network"
)

# --- desktop --------------------------------------------------------------
sw_desktop() {
    header "Desktop"
    local t cmd pkg req what missing=() bad_tools=0
    for t in "${TOOLS[@]}"; do
        IFS=: read -r cmd pkg req what <<<"$t"
        have "$cmd" && continue
        missing+=("$pkg")
        if [ "$req" = 1 ]; then bad "$cmd missing — needed for $what"; bad_tools=1
        else warn "$cmd missing (optional) — used for $what"; fi
    done
    local helper; helper="$(aur_helper)"
    [ -n "$helper" ] || { warn "no AUR helper (paru or yay) — AUR packages won't update"; missing+=(paru); }
    [ "$bad_tools" -eq 0 ] && ok "all required tools installed"
    [ ${#missing[@]} -eq 0 ] || hint "install with: $SELF_NAME packages install ${missing[*]}"

    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || ! hyprctl version >/dev/null 2>&1; then
        warn "not inside a Hyprland session — skipping desktop checks"
        return
    fi
    ok "Hyprland $(hyprctl version -j 2>/dev/null | jq -r '.tag // .version // empty' 2>/dev/null)"

    pgrep -x awww-daemon >/dev/null && ok "wallpaper daemon (awww-daemon) running" \
        || { bad "awww-daemon not running"; hint "start it: awww-daemon & disown; then $SELF_NAME profile apply"; }

    pgrep -x eww >/dev/null && ok "eww bar running" \
        || { bad "eww not running"; hint "start it: eww daemon && eww open bar"; }

    local n
    n="$(pgrep -fc '^bash .*hotplug-daemon\.sh' || true)"
    if   [ "$n" -eq 1 ]; then ok "monitor hotplug watcher running"
    elif [ "$n" -gt 1 ]; then warn "$n copies of the hotplug watcher running (harmless, 1 is enough)"
    else warn "hotplug watcher not running — wallpapers won't come back when a screen turns on"
         hint "start it: ~/.config/profiles/hotplug-daemon.sh & disown"; fi

    local cur mon
    cur="$(cat "$PROFILES/.current" 2>/dev/null || echo default)"
    if [ -d "$PROFILES/$cur" ]; then
        ok "active profile: $cur"
        for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
            ls "$PROFILES/$cur/wallpapers/$mon".* >/dev/null 2>&1 \
                || { warn "$mon has no wallpaper in \"$cur\""; hint "$SELF_NAME profile wallpaper set <image> . $mon"; }
        done
    else
        bad "active profile \"$cur\" doesn't exist"
        hint "pick one: $SELF_NAME profile menu"
    fi
}

# --- services -------------------------------------------------------------
# Every service enabled on this machine (system and user), as
# "scope<TAB>name<TAB>type<TAB>state<TAB>started" lines.
enabled_services() {
    local scope units
    for scope in system user; do
        local f=(); [ "$scope" = user ] && f=(--user)
        units="$(systemctl "${f[@]}" list-unit-files --type=service --state=enabled --no-legend 2>/dev/null \
                 | awk '$1 !~ /@/ {print $1}')"
        [ -n "$units" ] || continue
        # shellcheck disable=SC2086
        systemctl "${f[@]}" show -p Id -p Type -p ActiveState -p ActiveEnterTimestamp $units 2>/dev/null \
            | awk -v scope="$scope" -F= -v OFS='\t' '
                /^Id=/ {id = $2} /^Type=/ {type = $2} /^ActiveState=/ {state = $2}
                /^ActiveEnterTimestamp=/ {ts = $2}
                /^$/ { if (id != "") print scope, id, type, state, ts; id = type = state = ts = "" }
                END { if (id != "") print scope, id, type, state, ts }'
    done
}

# Is a stopped service fine? One-shot jobs finish and stop; D-Bus and
# socket-activated ones start only when something asks for them.
stopped_is_fine() {   # scope name type
    local f=(); [ "$1" = user ] && f=(--user)
    [ "$3" = oneshot ] || [ "$3" = dbus ] && return 0
    [ "$(systemctl "${f[@]}" is-active "${2%.service}.socket" 2>/dev/null)" = active ]
}

sw_services() {   # pass "full" to list every running service
    header "Services"
    local scope name type state ts running=0 list="" failed ufailed u
    while IFS=$'\t' read -r scope name type state ts; do
        [ -n "$name" ] || continue
        local label="${name%.service}"; [ "$scope" = user ] && label="$label ${C_DIM}(user)${C_RESET}"
        if [ "$state" = active ]; then
            running=$((running + 1))
            list+="$(printf '    %s✓%s %-28s %s%s%s' "$C_GREEN" "$C_RESET" "$label" "$C_DIM" \
                "$(if [ "$type" = oneshot ]; then echo "ran once at startup"; elif [ -n "$ts" ]; then date -d "$ts" '+since %b %d %H:%M' 2>/dev/null; fi)" "$C_RESET")"$'\n'
        elif [ "$state" = failed ]; then
            :   # reported below with the other failed units
        elif ! stopped_is_fine "$scope" "$name" "$type"; then
            warn "$label is enabled but not running ($state)"
            hint "details: systemctl $([ "$scope" = user ] && echo '--user ')status ${name%.service}"
        fi
    done < <(enabled_services)
    failed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')"
    ufailed="$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}')"
    if [ -z "$failed$ufailed" ]; then
        ok "$running enabled services running, none failed"
        [ "${1:-}" = full ] && printf '%s' "$list"
    else
        ok "$running enabled services running"
        [ "${1:-}" = full ] && printf '%s' "$list"
        for u in $failed;  do bad "failed: $u"; hint "details: systemctl status $u"; done
        for u in $ufailed; do bad "failed (user): $u"; hint "details: systemctl --user status $u"; done
    fi
}

# --- processes ------------------------------------------------------------
sw_processes() {
    header "Processes"
    local total zombies
    total="$(ps -e --no-headers | wc -l)"
    printf '  %s processes running\n\n' "$total"

    # top's second sample is a real measurement (the first is since boot).
    echo "  ${C_BOLD}busiest right now${C_RESET}  ${C_DIM}(100% = one full core)${C_RESET}"
    top -b -n2 -d0.5 -w 200 2>/dev/null | awk '/^top -/{n++} n==2 && /^ *[0-9]/ && $NF != "top"' \
        | head -n 6 | while read -r pid _ _ _ _ _ _ _ cpu _ _ cmd; do
            printf '    %5s%%  %-20s %spid %s%s\n' "$cpu" "$cmd" "$C_DIM" "$pid" "$C_RESET"
        done

    echo
    echo "  ${C_BOLD}most memory${C_RESET}  ${C_DIM}(all processes of a program added up)${C_RESET}"
    ps -eo rss=,comm= | awk '{m[$2]+=$1*1024; c[$2]++} END {for (n in m) print m[n], c[n], n}' \
        | sort -rn | head -n 6 | while read -r b c n; do
            printf '    %-9s %-20s %s%s process%s%s\n' "$(human "$b")" "$n" "$C_DIM" "$c" "$([ "$c" -gt 1 ] && echo es)" "$C_RESET"
        done

    zombies="$(ps -eo stat=,pid=,ppid=,comm= | awk '$1 ~ /^Z/')"
    echo
    if [ -z "$zombies" ]; then
        ok "no zombie processes"
    else
        warn "$(wc -l <<<"$zombies") zombie process(es) — finished, but their parent never cleaned up:"
        while read -r _ pid ppid comm; do
            hint "$comm (pid $pid), parent: $(ps -o comm= -p "$ppid" 2>/dev/null) (pid $ppid)"
        done <<<"$zombies"
    fi
}

# --- logs -----------------------------------------------------------------
crashes_since() {   # <journal time, e.g. -24h> → "time<TAB>program<TAB>signal" lines
    coredumpctl list --since "$1" --no-pager --json=short 2>/dev/null \
        | jq -r '.[] | [(.time / 1000000 | strflocaltime("%b %d %H:%M")), (.exe | split("/") | last), .sig] | @tsv' 2>/dev/null
}

sw_logs() {
    header "Logs"
    local errs crashes
    errs="$(journalctl -b -p 3 -q --no-pager -o cat 2>/dev/null)"
    if [ -z "$errs" ]; then
        ok "no errors logged since boot"
    else
        printf '  %s errors logged since boot %s(most are harmless noise)%s, most common:\n' \
            "$(wc -l <<<"$errs")" "$C_DIM" "$C_RESET"
        sort <<<"$errs" | uniq -c | sort -rn | head -n 6 | while read -r c msg; do
            printf '    %s%4sx%s %s\n' "$C_DIM" "$c" "$C_RESET" "${msg:0:100}"
        done
        hint "all of them: journalctl -b -p 3"
    fi

    echo
    crashes="$(crashes_since -7d)"
    if [ -z "$crashes" ]; then
        ok "no program crashes in the last 7 days"
    else
        warn "$(wc -l <<<"$crashes") program crash(es) in the last 7 days:"
        while IFS=$'\t' read -r t exe sig; do
            hint "$t  $exe (signal $sig)"
        done <<<"$crashes"
        hint "details: coredumpctl info <program>"
    fi
}

# --- packages -------------------------------------------------------------
last_update_days() {
    local ts
    ts="$(grep 'starting full system upgrade' /var/log/pacman.log 2>/dev/null | tail -n1 | sed 's/^\[\([^]]*\)\].*/\1/')"
    [ -n "$ts" ] || return 0
    echo $(( ( $(date +%s) - $(date -d "$ts" +%s) ) / 86400 ))
}

sw_packages() {   # pass "full" to list .pacnew files
    header "Packages"
    local days pacnew orphans cache paru_cache f
    days="$(last_update_days)"
    if   [ -z "$days" ];        then warn "can't tell when the system was last updated"
    elif [ "$days" -ge 21 ];    then warn "last full update was $days days ago"; hint "update: $SELF_NAME update"
    elif [ "$days" -eq 0 ];     then ok "last full update: today"
    else ok "last full update: $days day(s) ago"; fi

    if [ -d "/usr/lib/modules/$(uname -r)" ]; then
        ok "running the installed kernel ($(uname -r))"
    else
        warn "kernel was updated since boot — reboot to finish the update"
    fi

    pacnew="$(find /etc -name '*.pacnew' 2>/dev/null)"
    if [ -z "$pacnew" ]; then
        ok "no .pacnew config files"
    else
        warn "$(wc -l <<<"$pacnew") .pacnew config file(s) — new defaults to compare with your version"
        if [ "${1:-}" = full ]; then
            while read -r f; do hint "$f"; done <<<"$pacnew"
        else
            hint "list them: $SELF_NAME health software packages"
        fi
    fi

    orphans="$(pacman -Qqdt 2>/dev/null | wc -l)"
    [ "$orphans" -eq 0 ] && ok "no orphaned packages" \
        || { warn "$orphans orphaned package(s)"; hint "see them: $SELF_NAME packages --orphans   remove: $SELF_NAME packages remove --orphans"; }

    cache="$(du -sb /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
    # AUR helper build caches (paru and/or yay).
    paru_cache="$(du -scb "$HOME/.cache/paru" "$HOME/.cache/yay" 2>/dev/null | tail -n1 | cut -f1)"
    cache=$(( ${cache:-0} + ${paru_cache:-0} ))
    if [ "$cache" -gt $(( 10 * 1024 ** 3 )) ]; then
        warn "package caches use $(human "$cache") (pacman + AUR builds)"
        hint "clean up: $SELF_NAME packages clean"
    else
        ok "package caches $(human "$cache")"
    fi
}

software_show() {
    local s
    [ $# -gt 0 ] || set -- $SOFTWARE_SECTIONS
    for s in "$@"; do
        case "$s" in
            desktop)               sw_desktop ;;
            services)              sw_services full ;;
            processes|process|ps)  sw_processes ;;
            logs|log)              sw_logs ;;
            packages|pkgs)         sw_packages full ;;
            *) die "unknown software section: $s (choose from: $SOFTWARE_SECTIONS)" ;;
        esac
    done
}

software_check() {
    sw_desktop
    sw_services
    sw_packages
    header "Crashes"
    local crashes
    crashes="$(crashes_since -24h)"
    if [ -z "$crashes" ]; then
        ok "no program crashes in the last 24 hours"
    else
        warn "crashed in the last 24 hours: $(cut -f2 <<<"$crashes" | sort -u | tr '\n' ' ')"
        hint "details: $SELF_NAME health software logs"
    fi
}
