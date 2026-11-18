#!/usr/bin/env python3
import json
import datetime
from zoneinfo import ZoneInfo
from adhan import adhan
from adhan.methods import KARACHI, ASR_STANDARD

from pathlib import Path

# --- CONFIGURATION ---
# Location comes from ~/.config/eww/location.conf (one per machine, not in
# the repo), falling back to location.conf.example.
EWW_DIR = Path(__file__).resolve().parent.parent


def read_location():
    path = EWW_DIR / "location.conf"
    if not path.exists():
        path = EWW_DIR / "location.conf.example"
    values = {}
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip("\"'")
    return values["CITY"], float(values["LATITUDE"]), float(values["LONGITUDE"])


CITY, LAT, LONG = read_location()

# Clean Unicode character escapes mapping to Inter Regular glyph shapes
PRAYER_MAP = {
    "Fajr": {"icon": ""},     # nf-md-weather_sunset_up (Updated Dawn/Fajr Glyph)
    "Dhuhr": {"icon": ""},    # nf-fa-sun_o (No changes needed)
    "Asr": {"icon": ""},      # nf-md-weather_partly_cloudy (Updated Asr Glyph)
    "Maghrib": {"icon": ""},    # nf-fa-moon_o (No changes needed)
    "Isha": {"icon": "󰖔"}       # nf-md-weather_night (Updated Starry Night Glyph)
}

def timezone_offset_for(day):
    with open("/etc/localtime", "rb") as timezone_file:
        local_timezone = ZoneInfo.from_file(timezone_file)
    local_noon = datetime.datetime.combine(day, datetime.time(12), tzinfo=local_timezone)
    return local_noon.utcoffset().total_seconds() / 3600

def get_prayer_data():
    try:
        now = datetime.datetime.now()
        today = datetime.date.today()
        
        # Build parameter mapping strictly using the built-in library structures
        params = {}
        params.update(KARACHI)
        params.update(ASR_STANDARD)
        
        # Execute the calculation function using library convention
        prayers = adhan(
            day=today,
            location=(LAT, LONG),
            parameters=params,
            timezone_offset=timezone_offset_for(today)
        )
        
        # Standardize dict naming conventions returned by the adhan package
        prayer_times = {
            "Fajr": prayers["fajr"],
            "Dhuhr": prayers["zuhr"],
            "Asr": prayers["asr"],
            "Maghrib": prayers["maghrib"],
            "Isha": prayers["isha"]
        }

        daily_list = []
        next_prayer_name = None
        next_prayer_time = None
        min_diff = float('inf')

        for name in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]:
            p_time = prayer_times[name]
            formatted_time = p_time.strftime("%I:%M %p")
            
            daily_list.append({
                "name": name,
                "icon": PRAYER_MAP[name]["icon"],
                "time": formatted_time
            })

            # Calculate precise remaining time offsets relative to system clock
            diff = (p_time - now).total_seconds()
            if 0 < diff < min_diff:
                min_diff = diff
                next_prayer_name = name
                next_prayer_time = p_time

        # Rollover safety fallback: if all prayers today have passed, target tomorrow's Fajr
        if not next_prayer_name:
            next_prayer_name = "Fajr"
            tomorrow = today + datetime.timedelta(days=1)
            tomorrow_prayers = adhan(
                day=tomorrow,
                location=(LAT, LONG),
                parameters=params,
                timezone_offset=timezone_offset_for(tomorrow)
            )
            next_prayer_time = tomorrow_prayers["fajr"]

        formatted_next_time = next_prayer_time.strftime("%I:%M %p")

        return {
            "city": CITY,
            "lat": f"{LAT:.2f}° N",
            "long": f"{LONG:.2f}° W",
            "next_name": next_prayer_name,
            "next_time": formatted_next_time,
            "next_icon": PRAYER_MAP[next_prayer_name]["icon"],
            "daily": daily_list
        }

    except Exception as e:
        return {
            "city": "Error", 
            "lat": "N/A", 
            "long": "N/A", 
            "next_name": "Crash", 
            "next_time": str(e)[:15], 
            "next_icon": "\u26a0", 
            "daily": []
        }

if __name__ == "__main__":
    print(json.dumps(get_prayer_data()))
