#!/usr/bin/env bash
# Current weather for the bar, as one line of JSON:
#   {"icon":"󰖙","desc":"Clear","temp":"72°"}
# Icons follow the weather code and day/night. Location (and optionally
# TEMP_UNIT=celsius) comes from ../location.conf. If the network is down, the
# last good result is shown; with no result at all yet, it retries a few
# times (the bar starts before Wi-Fi is up).

EWW_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
conf="$EWW_DIR/location.conf"; [ -f "$conf" ] || conf="$EWW_DIR/location.conf.example"
. "$conf"
CACHE="$HOME/.cache/eww-weather/now.json"
mkdir -p "$(dirname "$CACHE")"

unit="${TEMP_UNIT:-fahrenheit}"
url="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,weather_code,is_day&temperature_unit=${unit}&timezone=auto"

# icon, then description, for a WMO weather code ($1) and is_day ($2)
describe() {
    local day="$2"
    case "$1" in
        0)          [ "$day" = 1 ] && echo $'\U000F0599 Clear' || echo $'\U000F0594 Clear' ;;
        1)          [ "$day" = 1 ] && echo $'\U000F0595 Mostly clear' || echo $'\U000F0F31 Mostly clear' ;;
        2)          [ "$day" = 1 ] && echo $'\U000F0595 Partly cloudy' || echo $'\U000F0F31 Partly cloudy' ;;
        3)          echo $'\U000F0590 Overcast' ;;
        45|48)      echo $'\U000F0591 Fog' ;;
        51|53|55|56|57) echo $'\U000F0597 Drizzle' ;;
        61|63|66|80|81) echo $'\U000F0597 Rain' ;;
        65|67|82)   echo $'\U000F0596 Heavy rain' ;;
        71|73|75|77|85|86) echo $'\U000F0598 Snow' ;;
        95|96|99)   echo $'\U000F0593 Thunderstorm' ;;
        *)          echo $'\U000F0590 Cloudy' ;;
    esac
}

fetch() {
    local r code day temp line
    r="$(curl -sf --max-time 10 "$url")" || return 1
    code="$(jq -r '.current.weather_code // empty' <<<"$r")"
    day="$(jq -r '.current.is_day // 1' <<<"$r")"
    temp="$(jq -r '.current.temperature_2m // empty | round' <<<"$r")"
    [ -n "$code" ] && [ -n "$temp" ] || return 1
    line="$(describe "$code" "$day")"
    jq -nc --arg icon "${line%% *}" --arg desc "${line#* }" --arg temp "${temp}°" \
        '{icon:$icon, desc:$desc, temp:$temp}' | tee "$CACHE"
}

for try in 1 2 3 4 5 6; do
    fetch && exit 0
    [ -s "$CACHE" ] && { cat "$CACHE"; exit 0; }
    sleep 10
done
jq -nc --arg icon $'\U000F0590' '{icon:$icon, desc:"Offline", temp:""}'
