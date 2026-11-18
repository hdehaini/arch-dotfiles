# health hardware — CPU, GPU, RAM, disks, fans, batteries. Sourced by
# commands/health. Everything is discovered at run time from /proc, /sys,
# lspci, lsblk (and nvidia-smi for NVIDIA cards), so it works on any machine.
#   hardware_show [part...]   detailed stats; HW_KINDS filters the lines
#   hardware_check            ✓ / ! / ✗ checks for `health`

HARDWARE_PARTS="cpu gpu ram disks fans battery"

# --- output: every line has a kind, so --usage / --temps can filter ---------
#   info   what the part is (model, uptime, notes)
#   usage  how busy / full it is (%, clocks, power, charge)
#   temp   temperatures and fan speeds
HW_KINDS="info usage temp"     # commands/health narrows this for --usage/--temps
HW_PRINTED=0
_PENDING="" _PENDING_SUB="" _SUB_COUNT=0

part()    { _PENDING="$1"; _PENDING_SUB=""; _SUB_COUNT=0; }   # e.g. "GPU"
subpart() { _PENDING_SUB="$1"; }                              # e.g. one card

_flush() {
    if [ -n "$_PENDING" ]; then header "$_PENDING"; _PENDING=""; fi
    if [ -n "$_PENDING_SUB" ]; then
        [ "$_SUB_COUNT" -gt 0 ] && echo
        printf '  %s\n' "$_PENDING_SUB"
        _PENDING_SUB=""; _SUB_COUNT=$((_SUB_COUNT + 1))
    fi
    HW_PRINTED=1
}

# line <kind> <text>   /   row <kind> <label> <value>
line() { [[ " $HW_KINDS " == *" $1 "* ]] || return 0; _flush; printf '%s\n' "$2"; }
row()  { line "$1" "$(printf '  %-10s %s' "$2" "$3")"; }

# Graphics cards: "device-path<TAB>pci-slot<TAB>vendor-id<TAB>short name"
gpus() {
    local card dev slot name seen=" "
    for card in /sys/class/drm/card*; do
        [[ "$(basename "$card")" =~ ^card[0-9]+$ ]] || continue
        dev="$(readlink -f "$card/device")"
        [[ "$dev" == */pci* ]] || continue          # skip virtual displays
        slot="$(basename "$dev")"
        [[ "$seen" == *" $slot "* ]] && continue; seen+="$slot "
        name="$(lspci -s "$slot" -vmm 2>/dev/null | awk -F'\t' '/^Device:/{print $2; exit}')"
        # "Navi 22 [Radeon RX 6700/...]" → "Radeon RX 6700/..."
        [[ "$name" =~ \[(.*)\] ]] && name="${BASH_REMATCH[1]}"
        printf '%s\t%s\t%s\t%s\n' "$dev" "$slot" "$(cat "$dev/vendor" 2>/dev/null || echo '?')" "${name:-$slot}"
    done
}

# NVIDIA's driver doesn't expose usage/temps in /sys; ask nvidia-smi.
# nvidia_stats <pci-slot> → "usage vram_used_MiB vram_total_MiB temp power_W power_limit_W fan%"
nvidia_stats() {
    have nvidia-smi || return 0
    nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed \
        --format=csv,noheader,nounits 2>/dev/null \
        | awk -F', *' -v s="${1#*:}" 'tolower($1) ~ tolower(s) "$" {print $2, $3, $4, $5, $6, $7, $8}'
}

# --- CPU ------------------------------------------------------------------
cpu_usage() {
    # Two samples of /proc/stat, 0.4s apart. Fields: user nice system idle
    # iowait irq softirq steal → total, idle.
    local t1 i1 t2 i2
    read -r t1 i1 < <(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
    sleep 0.4
    read -r t2 i2 < <(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}' /proc/stat)
    local dt=$(( t2 - t1 )) di=$(( i2 - i1 ))
    [ "$dt" -gt 0 ] && echo $(( (dt - di) * 100 / dt )) || echo 0
}

hw_cpu() {
    part "CPU"
    local model cores threads freqs
    model="$(awk -F': ' '/^model name|^Model|^Hardware/{print $2; exit}' /proc/cpuinfo)"
    [ -n "$model" ] || model="$(lscpu 2>/dev/null | awk -F': +' '/Model name/{print $2; exit}')"
    threads="$(nproc)"
    cores="$(lscpu -p=CORE,SOCKET 2>/dev/null | grep -v '^#' | sort -u | wc -l)"
    row info "model" "${model:-unknown} (${cores} cores / ${threads} threads)"
    if [[ " $HW_KINDS " == *" usage "* ]]; then
        row usage "usage" "$(bar "$(cpu_usage)")"
        freqs="$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null \
                 | awk '{s+=$1; if ($1>m) m=$1} END {if (NR) printf "%.2f GHz avg, %.2f GHz max", s/NR/1e6, m/1e6}')"
        [ -n "$freqs" ] && row usage "clock" "$freqs"
        row usage "load" "$(cut -d' ' -f1-3 /proc/loadavg)  ${C_DIM}(1, 5, 15 min)${C_RESET}"
    fi
    row temp "temp"   "$(show_temp_file "$(cpu_temp_file)" 85 95)"
    row info "uptime" "$(uptime -p | sed 's/^up //')"
}

# --- GPU ------------------------------------------------------------------
hw_gpu() {
    part "GPU"
    local dev slot vendor name busy vu vt hw f t pwr pcap fan any=0 parts
    while IFS=$'\t' read -r dev slot vendor name; do
        any=1
        subpart "$(printf '%s%s%s %s(%s)%s' "$C_BOLD" "$name" "$C_RESET" "$C_DIM" "$slot" "$C_RESET")"

        if [ "$vendor" = 0x10de ] && have nvidia-smi; then
            local u mu mt tt pw pl fs
            read -r u mu mt tt pw pl fs < <(nvidia_stats "$slot")
            [ -n "${u:-}" ] || { line info "  ${C_DIM}no stats from nvidia-smi${C_RESET}"; continue; }
            row usage "usage" "$(bar "$u")"
            [ "${mt:-0}" -gt 0 ] && row usage "vram" "$(bar $(( mu * 100 / mt )))  $(human $(( mu * 1048576 ))) / $(human $(( mt * 1048576 )))"
            row temp "temp" "$(temp "$tt" 83 90)"
            [[ "$pw" =~ ^[0-9] ]] && row usage "power" "${pw%.*} W${pl:+ / ${pl%.*} W limit}"
            [[ "$fs" =~ ^[0-9] ]] && row temp "fan" "${fs}%"
            continue
        elif [ "$vendor" = 0x10de ]; then
            line info "  ${C_DIM}install nvidia-utils for usage and temperature${C_RESET}"
        fi

        # AMD (and partly Intel) expose stats in sysfs.
        busy="$(cat "$dev/gpu_busy_percent" 2>/dev/null)"
        [ -n "$busy" ] && row usage "usage" "$(bar "$busy")"
        vu="$(cat "$dev/mem_info_vram_used" 2>/dev/null)"
        vt="$(cat "$dev/mem_info_vram_total" 2>/dev/null)"
        if [ -n "$vu" ] && [ "${vt:-0}" -gt 0 ]; then
            row usage "vram" "$(bar $(( vu * 100 / vt )))  $(human "$vu") / $(human "$vt")"
        fi

        hw="$(ls -d "$dev"/hwmon/hwmon* 2>/dev/null | head -n1)"
        [ -n "$hw" ] || continue
        # Every temperature the card reports, by its own label.
        parts=""
        for f in "$hw"/temp*_input; do
            [ -r "$f" ] || continue
            t="$(cat "${f%_input}_label" 2>/dev/null || echo temp)"
            [ "$t" = junction ] && t=hotspot
            parts+="${parts:+   }$(show_temp_file "$f" 80 95) $t"
        done
        [ -n "$parts" ] && row temp "temp" "$parts"
        pwr="$(cat "$hw/power1_average" 2>/dev/null || cat "$hw/power1_input" 2>/dev/null)"
        pcap="$(cat "$hw/power1_cap" 2>/dev/null)"
        if [ -n "$pwr" ] && grep -qx vddnb "$hw"/in*_label 2>/dev/null; then
            # Integrated AMD GPU: this sensor reports the whole CPU package.
            row usage "power" "$(( pwr / 1000000 )) W ${C_DIM}(whole CPU package — integrated GPU)${C_RESET}"
        elif [ -n "$pwr" ]; then
            row usage "power" "$(( pwr / 1000000 )) W${pcap:+ / $(( pcap / 1000000 )) W limit}"
        fi
        fan="$(cat "$hw/fan1_input" 2>/dev/null)"
        if [ -n "$fan" ]; then
            [ "$fan" -eq 0 ] && row temp "fan" "stopped ${C_DIM}(normal when cool)${C_RESET}" || row temp "fan" "$fan RPM"
        fi
    done < <(gpus)
    [ "$any" -eq 1 ] || line info "  no graphics cards found"
}

# --- RAM ------------------------------------------------------------------
meminfo() {   # → total available swap_total swap_free (bytes)
    awk '/^MemTotal/{a=$2} /^MemAvailable/{b=$2} /^SwapTotal/{c=$2} /^SwapFree/{d=$2}
         END{print a*1024, b*1024, c*1024, d*1024}' /proc/meminfo
}

# Temperature sensors on the RAM sticks themselves (DDR5 / some DDR4).
dimm_temp_files() {
    local d
    for d in $(hwmon_dirs 'spd5118|jc42'); do hwmon_temp_file "$d"; done
}

hw_ram() {
    part "Memory"
    local mt ma st sf used sused f temps=""
    read -r mt ma st sf < <(meminfo)
    used=$(( mt - ma ))
    row usage "ram" "$(bar $(( used * 100 / mt )) 20 80 92)  $(human "$used") / $(human "$mt")"
    if [ "$st" -gt 0 ]; then
        sused=$(( st - sf ))
        row usage "swap" "$(bar $(( sused * 100 / st )) 20 50 80)  $(human "$sused") / $(human "$st")"
    fi
    for f in $(dimm_temp_files); do temps+="${temps:+  }$(show_temp_file "$f" 55 80)"; done
    [ -n "$temps" ] && row temp "sticks" "$temps"
    line info "  ${C_DIM}which programs: $SELF_NAME health software processes${C_RESET}"
}

# --- Disks ----------------------------------------------------------------
physical_disks() {   # name<TAB>size<TAB>transport<TAB>removable<TAB>model
    lsblk -dJbo NAME,SIZE,TRAN,RM,MODEL | jq -r '
        .blockdevices[] | select(.name | test("^(zram|loop|sr|ram)") | not)
        | [.name, .size, (.tran // "?"), (if .rm then "1" else "0" end), (.model // "")] | @tsv'
}

hw_disks() {
    part "Disks"
    local name size model tran rm f label
    while IFS=$'\t' read -r name size tran rm model; do
        f="$(disk_temp_file "$name")"
        label="${model:-unknown model}"
        [ "$rm" = "1" ] && label="$label ${C_YELLOW}(removable)${C_RESET}"
        subpart "$(printf '%s%s%s  %s%s, %s, %s%s' "$C_BOLD" "$name" "$C_RESET" "$label" "$C_DIM" "$(human "$size")" "$tran" "$C_RESET")"
        if [ -n "$f" ]; then
            row temp "temp" "$(show_temp_file "$f" 60 70)"
        elif [ "$tran" = sata ]; then
            row temp "temp" "${C_DIM}not available — load the drivetemp module to see it (sudo modprobe drivetemp)${C_RESET}"
        fi

        local part fstype psize mnt s u
        while IFS=$'\t' read -r part fstype psize mnt; do
            if [ "$mnt" = "-" ]; then
                [ "$fstype" = "-" ] && fstype="no filesystem"
                line info "$(printf '    %-11s %s%-22s %s, %s%s' "$part" "$C_DIM" "not mounted" "$(human "$psize")" "$fstype" "$C_RESET")"
            elif [ "$mnt" = "[SWAP]" ]; then
                line info "$(printf '    %-11s %s%-22s %s%s' "$part" "$C_DIM" "swap" "$(human "$psize")" "$C_RESET")"
            else
                read -r s u < <(df -B1 --output=size,used "$mnt" 2>/dev/null | tail -n1)
                [ "${s:-0}" -gt 0 ] || continue
                line usage "$(printf '    %-11s %-22s %s  %s free of %s' "$part" "$mnt" \
                    "$(bar $(( u * 100 / s )) 16 80 90)" "$(human $(( s - u )))" "$(human "$s")")"
            fi
        done < <(lsblk -Jbo NAME,FSTYPE,SIZE,MOUNTPOINT "/dev/$name" | jq -r '
                    .blockdevices[0] | (.children // [.])[]
                    | [.name, (.fstype // "-"), .size, (.mountpoint // "-")] | @tsv')
    done < <(physical_disks)
}

# --- Fans -----------------------------------------------------------------
# Every fan any sensor reports, except graphics cards (shown under GPU).
hw_fans() {
    part "Fans"
    local d f rpm lbl any=0
    for d in /sys/class/hwmon/hwmon*; do
        grep -qE '^(amdgpu|radeon|nouveau|i915|xe)$' "$d/name" 2>/dev/null && continue
        for f in "$d"/fan*_input; do
            [ -r "$f" ] || continue
            rpm="$(cat "$f" 2>/dev/null)" || continue
            [ "${rpm:-0}" -gt 0 ] || continue
            lbl="$(cat "${f%_input}_label" 2>/dev/null || basename "${f%_input}")"
            row temp "$lbl" "$rpm RPM"
            any=1
        done
    done
    [ "$any" -eq 1 ] || line temp "  no spinning fans reported ${C_DIM}(the motherboard sensor driver may not be loaded — try: sudo sensors-detect)${C_RESET}"
}

# --- Batteries ------------------------------------------------------------
# Laptop batteries and wireless devices (mice, keyboards, controllers).
# batteries → path, name, percent (may be empty), level, status, laptop(1/0)
# separated by \x1f (not tabs: bash would merge empty tab-separated fields)
batteries() {
    local b name cap level status scope
    for b in /sys/class/power_supply/*; do
        [ "$(cat "$b/type" 2>/dev/null)" = Battery ] || continue
        name="$(cat "$b/model_name" 2>/dev/null)"
        [ -n "$name" ] || name="$(basename "$b")"
        cap="$(cat "$b/capacity" 2>/dev/null)"
        level="$(cat "$b/capacity_level" 2>/dev/null)"
        status="$(cat "$b/status" 2>/dev/null)"
        scope="$(cat "$b/scope" 2>/dev/null)"
        printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$b" "$name" "$cap" "$level" "$status" "$([ "$scope" = Device ] && echo 0 || echo 1)"
    done
}

hw_battery() {
    part "Battery"
    local list; list="$(batteries)"
    if [ -z "$list" ]; then
        [ "${1:-}" = quiet ] || line usage "  no batteries"
        return
    fi
    local b name cap level status laptop extra full design
    while IFS=$'\x1f' read -r b name cap level status laptop; do
        extra=""
        [ -n "$status" ] && [ "$status" != Unknown ] && extra="${C_DIM}${status,,}${C_RESET}"
        if [ "$laptop" = 1 ]; then
            # Battery health: how much it holds now vs. when new.
            full="$(cat "$b/energy_full" 2>/dev/null || cat "$b/charge_full" 2>/dev/null)"
            design="$(cat "$b/energy_full_design" 2>/dev/null || cat "$b/charge_full_design" 2>/dev/null)"
            [ "${design:-0}" -gt 0 ] && extra+="  ${C_DIM}health $(( full * 100 / design ))%${C_RESET}"
        fi
        if [ -n "$cap" ]; then
            # Low is bad here, so color by how empty it is.
            local col s="" i
            col="$(level_color $(( 100 - cap )) 80 90)"
            for (( i = 0; i < 10; i++ )); do [ "$i" -lt $(( cap / 10 )) ] && s+="█" || s+="░"; done
            line usage "$(printf '  %-32s %s%s %3d%%%s  %s' "${name:0:32}" "$col" "$s" "$cap" "$C_RESET" "$extra")"
        else
            { [ -z "$level" ] || [ "$level" = Unknown ]; } && level="${C_DIM}no charge level reported${C_RESET}"
            line usage "$(printf '  %-32s %s  %s' "${name:0:32}" "$level" "$extra")"
        fi
    done <<<"$list"
}

hardware_show() {
    local s
    HW_PRINTED=0
    if [ $# -eq 0 ]; then
        hw_cpu; hw_gpu; hw_ram; hw_disks; hw_fans; hw_battery quiet
    else
        for s in "$@"; do
            case "$s" in
                cpu)                 hw_cpu ;;
                gpu)                 hw_gpu ;;
                ram|mem|memory)      hw_ram ;;
                disks|disk|storage)  hw_disks ;;
                fans|fan)            hw_fans ;;
                battery|batteries)   hw_battery ;;
                *) die "unknown hardware part: $s (choose from: $HARDWARE_PARTS)" ;;
            esac
        done
    fi
    [ "$HW_PRINTED" = 1 ] || echo "nothing to show for: ${*:-all parts} (${HW_KINDS// /, })"
}

# --- checks ---------------------------------------------------------------
hardware_check() {
    local src size used pct mnt p free dev slot vendor name hw f t d mt ma mp

    header "Disk space"
    while read -r src size used pct mnt; do
        p="${pct%\%}"; free="$(human $(( size - used )))"
        if   [ "$p" -ge 95 ]; then bad  "$mnt is ${p}% full ($free free)"
        elif [ "$p" -ge 85 ]; then warn "$mnt is ${p}% full ($free free)"
        else ok "$mnt ${p}% full ($free free)"; fi
    done < <(df -B1 --output=source,size,used,pcent,target -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay 2>/dev/null | tail -n +2)

    header "Temperatures"
    check_temp_file "CPU" "$(cpu_temp_file)" 85 95
    while IFS=$'\t' read -r dev slot vendor name; do
        name="${name%%/*}"   # "Radeon RX 6700/6700 XT/..." → "Radeon RX 6700"
        if [ "$vendor" = 0x10de ]; then
            read -r _ _ _ t _ < <(nvidia_stats "$slot")
            if [ -n "${t:-}" ]; then
                if   [ "$t" -ge 90 ]; then bad "GPU $name is very hot: $(temp "$t" 83 90)"
                elif [ "$t" -ge 83 ]; then warn "GPU $name is warm: $(temp "$t" 83 90)"
                else ok "GPU $name $(temp "$t" 83 90)"; fi
            fi
            continue
        fi
        hw="$(ls -d "$dev"/hwmon/hwmon* 2>/dev/null | head -n1)"
        [ -n "$hw" ] || continue
        f="$(hwmon_temp_file "$hw" junction)"
        if [ -n "$f" ]; then check_temp_file "GPU $name (hotspot)" "$f" 95 105
        else check_temp_file "GPU $name" "$(hwmon_temp_file "$hw")" 85 95; fi
    done < <(gpus)
    while IFS=$'\t' read -r d _; do
        check_temp_file "disk $d" "$(disk_temp_file "$d")" 60 70
    done < <(physical_disks)
    local i=0
    for f in $(dimm_temp_files); do i=$((i + 1)); check_temp_file "RAM stick $i" "$f" 55 80; done

    header "Memory"
    read -r mt ma _ < <(meminfo)
    mp=$(( (mt - ma) * 100 / mt ))
    if   [ "$mp" -ge 95 ]; then bad  "RAM ${mp}% used"
    elif [ "$mp" -ge 85 ]; then warn "RAM ${mp}% used"
    else ok "RAM ${mp}% used"; fi

    local list; list="$(batteries)"
    [ -n "$list" ] || return 0
    header "Batteries"
    local b cap level status laptop
    while IFS=$'\x1f' read -r b name cap level status laptop; do
        [ "$status" = Charging ] && { ok "$name charging"; continue; }
        if [ -n "$cap" ]; then
            if   [ "$cap" -le 10 ]; then bad  "$name battery ${cap}%"
            elif [ "$cap" -le 20 ]; then warn "$name battery ${cap}%"
            else ok "$name battery ${cap}%"; fi
        elif [[ "$level" =~ ^(Low|Critical)$ ]]; then
            warn "$name battery ${level,,}"
        else
            ok "$name battery (no level reported)"
        fi
    done <<<"$list"
}
