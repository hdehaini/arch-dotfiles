# health network — connections, Wi-Fi, and whether the internet works.
# Sourced by commands/health.
#   network_show    detailed view
#   network_check   quick ✓ / ! / ✗ lines for `health`

# ping_stats <host> → "avg_ms loss%" (avg empty if no reply)
ping_stats() {
    ping -c 3 -i 0.2 -W 1 -q "$1" 2>/dev/null | awk -F'[/ ]+' '
        /packet loss/ { for (i = 1; i <= NF; i++) if ($i ~ /%$/) loss = $i }
        /^rtt|^round-trip/ { avg = sprintf("%.1f", $8) }
        END { printf "%s %s\n", avg, (loss == "" ? "100%" : loss) }'
}

# The connection the internet goes through: "dev<TAB>gateway" (lowest metric).
default_route() {
    ip -j route show default 2>/dev/null | jq -r 'sort_by(.metric // 0) | .[0] // empty | [.dev, .gateway] | @tsv'
}

# link_type <device> → wifi / ethernet / vpn / bridge / ... (no NetworkManager needed)
link_type() {
    local d="/sys/class/net/$1"
    if   [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; then echo wifi
    elif [ -d "$d/bridge" ]; then echo bridge
    elif [[ "$1" =~ ^(tun|tap|wg|tailscale) ]] || [ "$(cat "$d/type" 2>/dev/null)" = 65534 ]; then echo vpn
    elif [ -e "$d/device" ]; then echo ethernet
    else echo virtual; fi
}

# Connectivity tests, shared by both views.
net_tests() {
    local dev gw avg loss
    IFS=$'\t' read -r dev gw < <(default_route)
    if [ -z "${dev:-}" ]; then
        bad "not connected to any network"
        hint "connect: nmcli device wifi connect <name> --ask   (or plug in ethernet)"
        return
    fi
    local type
    type="$(link_type "$dev")"
    ok "online through $dev${type:+ ($type)}"

    if [ -n "${gw:-}" ]; then
        read -r avg loss < <(ping_stats "$gw")
        if [ -z "$avg" ]; then bad "router ($gw) not answering"; hint "try restarting the router, or: nmcli networking off && nmcli networking on"
        elif [ "$loss" != "0%" ]; then warn "router ($gw) answers, but $loss of pings were lost"
        else ok "router ($gw) ${avg} ms"; fi
    fi

    read -r avg loss < <(ping_stats 1.1.1.1)
    if [ -z "$avg" ]; then bad "internet not reachable (no reply from 1.1.1.1)"
    elif [ "$loss" != "0%" ]; then warn "internet reachable, but $loss of pings were lost (${avg} ms)"
    else ok "internet ${avg} ms ${C_DIM}(ping to 1.1.1.1)${C_RESET}"; fi

    if getent hosts archlinux.org >/dev/null 2>&1; then
        ok "DNS works ${C_DIM}(archlinux.org resolves)${C_RESET}"
    else
        bad "DNS not working — websites by name won't load"
        hint "DNS servers in use: $(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf)"
    fi
}

network_show() {
    header "Connections"
    local dev state ip4 primary conn mark
    primary="$(default_route | cut -f1)"
    # Every network interface the kernel knows about (no NetworkManager needed).
    while read -r dev state; do
        [[ "$dev" =~ ^(lo|veth|br-|p2p-dev) ]] && continue
        dev="${dev%@*}"
        ip4="$(ip -j -4 addr show dev "$dev" 2>/dev/null | jq -r '[.[].addr_info[].local] | join(", ")')"
        conn=""
        have nmcli && conn="$(nmcli -g GENERAL.CONNECTION device show "$dev" 2>/dev/null)"
        mark=""; [ "$dev" = "$primary" ] && mark=" ${C_GREEN}← internet goes through this${C_RESET}"
        if [ -n "$ip4" ]; then
            printf '  %s%-11s%s %-9s %-22s %s%s\n' "$C_BOLD" "$dev" "$C_RESET" "$(link_type "$dev")" "${conn:-}" "$ip4" "$mark"
        else
            printf '  %s%-11s %-9s %s%s\n' "$C_DIM" "$dev" "$(link_type "$dev")" "${state,,}, no address" "$C_RESET"
        fi
    done < <(ip -br link | awk '{print $1, $2}')

    # Wi-Fi details for the network we're on (needs NetworkManager).
    local active ssid signal rate sec chan band
    active=""
    have nmcli && active="$(nmcli -t -f ACTIVE,SSID,SIGNAL,RATE,SECURITY,CHAN dev wifi 2>/dev/null | grep '^yes:' | head -n1)"
    if [ -n "$active" ]; then
        IFS=: read -r _ ssid signal rate sec chan <<<"$active"
        band="2.4 GHz"; [ "${chan:-0}" -gt 14 ] && band="5 GHz"; [ "${chan:-0}" -gt 177 ] && band="6 GHz"
        header "Wi-Fi"
        printf '  %-10s %s\n' network "$ssid ${C_DIM}($sec, $band, channel $chan)${C_RESET}"
        # Signal is good when high, so flip the bar's colors.
        local scol; scol="$(level_color $(( 100 - signal )) 40 60)"
        printf '  %-10s %s%s%%%s\n' signal "$scol" "$signal" "$C_RESET"
        printf '  %-10s %s\n' speed "$rate ${C_DIM}(link speed, not internet speed)${C_RESET}"
    fi

    header "DNS"
    awk '/^nameserver/{print "  " $2}' /etc/resolv.conf
    grep -q '^nameserver 100\.100\.100\.100' /etc/resolv.conf \
        && echo "  ${C_DIM}(100.100.100.100 is Tailscale's DNS — it forwards everything else)${C_RESET}"

    header "Tests"
    net_tests
}

network_check() {
    header "Connection"
    net_tests
}
