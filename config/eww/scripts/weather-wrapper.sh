#!/bin/bash

# Read one value from location.conf (or the example if there's none yet).
location() {
    local dir; dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    local f="$dir/location.conf"; [ -f "$f" ] || f="$dir/location.conf.example"
    ( . "$f"; eval "echo \"\${$1:-Unknown}\"" )
}
# Wrapper script untuk weather agar output JSON friendly untuk Eww
CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww/}"
WEATHER_SCRIPT="$CONFIG_DIR/scripts/weather.sh"
# Cache file untuk menyimpan data terakhir yang berhasil
CACHE_DIR="$HOME/.cache/eww-weather"
CACHE_ICON="$CACHE_DIR/icon"
CACHE_DESC="$CACHE_DIR/desc"
CACHE_TEMP="$CACHE_DIR/temp"
mkdir -p "$CACHE_DIR"
case "$1" in
    temp)
        FULL_OUTPUT=$($WEATHER_SCRIPT current 2>/dev/null)
        TEMP=$(echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | grep -oP '\d+°[CF]' | head -1)
        
        if [ -n "$TEMP" ]; then
            echo "$TEMP" | tee "$CACHE_TEMP"
        elif [ -f "$CACHE_TEMP" ]; then
            cat "$CACHE_TEMP"
        else
            echo "N/A"
        fi
        ;;
    
    icon)
        FULL_OUTPUT=$($WEATHER_SCRIPT current 2>/dev/null)
        CLEAN_OUTPUT=$(echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g')
        ICON=$(echo "$CLEAN_OUTPUT" | awk '{print $1}' | xargs)
        
        if [ -n "$ICON" ]; then
            echo "$ICON" | tee "$CACHE_ICON"
        elif [ -f "$CACHE_ICON" ]; then
            cat "$CACHE_ICON"
        else
            echo "󰖐"  # Icon offline/loading
        fi
        ;;
    
    desc)
        FULL_OUTPUT=$($WEATHER_SCRIPT current 2>/dev/null)
        DESC=$(echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | sed 's/[|].*//g' | awk '{$1=""; print $0}' | sed 's/[0-9]*°[CF]//g' | xargs)
        
        if [ -n "$DESC" ]; then
            echo "$DESC" | tee "$CACHE_DESC"
        elif [ -f "$CACHE_DESC" ]; then
            cat "$CACHE_DESC"
        else
            echo "No Connection"
        fi
        ;;
    
    full)
        $WEATHER_SCRIPT current 2>/dev/null | sed 's/%{[^}]*}//g'
        ;;
    
    city)
        location CITY
        ;;
    
    latitude|lat)
        location LATITUDE | cut -c1-5
        ;;
    
    longitude|lon|long)
        location LONGITUDE | cut -c1-5
        ;;
    
    *)
        FULL_OUTPUT=$($WEATHER_SCRIPT current 2>/dev/null)
        echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | grep -oP '\d+°[CF]' | head -1 || echo "N/A"
        ;;
esac
