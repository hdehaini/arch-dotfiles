#!/usr/bin/env python3
import json
import datetime
import time
import sys
import subprocess
from pathlib import Path
from zoneinfo import ZoneInfo
from adhan import adhan
from adhan.methods import KARACHI, ASR_STANDARD

# --- CONFIGURATION ---
EWW_DIR = Path(__file__).resolve().parent.parent


def read_location():
    """CITY / LATITUDE / LONGITUDE from location.conf (one per machine, not
    in the repo), falling back to location.conf.example."""
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

# Path to your local Adhan audio file
ADHAN_AUDIO_PATH = str(EWW_DIR / "assets" / "adhan-0.mp3")
ADHAN_PID_FILE = Path("/tmp/eww-adhan.pid")

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

def get_prayer_times():
    today = datetime.date.today()
    params = {}
    params.update(KARACHI)
    params.update(ASR_STANDARD)
    
    prayers = adhan(
        day=today,
        location=(LAT, LONG),
        parameters=params,
        timezone_offset=timezone_offset_for(today),
    )
    return {
        "Fajr": prayers["fajr"],
        "Dhuhr": prayers["zuhr"],
        "Asr": prayers["asr"],
        "Maghrib": prayers["maghrib"],
        "Isha": prayers["isha"]
    }

def calculate_state():
    now = datetime.datetime.now()
    prayer_times = get_prayer_times()
    
    daily_list = []
    next_prayer_name = None
    next_prayer_time = None
    min_diff = float('inf')

    for name in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]:
        p_time = prayer_times[name]
        daily_list.append({
            "name": name,
            "icon": PRAYER_MAP[name]["icon"],
            "time": p_time.strftime("%I:%M %p"),
            "is_next": False # Used later for dynamic SCSS styling mapping highlights
        })

        diff = (p_time - now).total_seconds()
        if 0 < diff < min_diff:
            min_diff = diff
            next_prayer_name = name
            next_prayer_time = p_time

    if not next_prayer_name:
        next_prayer_name = "Fajr"
        tomorrow = datetime.date.today() + datetime.timedelta(days=1)
        params = {}
        params.update(KARACHI)
        params.update(ASR_STANDARD)
        tomorrow_prayers = adhan(
            day=tomorrow,
            location=(LAT, LONG),
            parameters=params,
            timezone_offset=timezone_offset_for(tomorrow),
        )
        next_prayer_time = tomorrow_prayers["fajr"]

    # Mark the exact next prayer in our array list
    for item in daily_list:
        if item["name"] == next_prayer_name:
            item["is_next"] = True

    # next_prayer_time = datetime.datetime.now() + datetime.timedelta(seconds=20)
    
    return {
        "city": CITY,
        "lat": f"{LAT:.2f}° N",
        "long": f"{LONG:.2f}° W",
        "next_name": next_prayer_name,
        "next_time": next_prayer_time.strftime("%I:%M %p"),
        "next_icon": PRAYER_MAP[next_prayer_name]["icon"],
        "daily": daily_list
    }, next_prayer_time

def main():
    last_prayer_triggered = None
    
    while True:
        output_json, next_time = calculate_state()
        
        # Stream structured string output to standard system stdout channels
        sys.stdout.write(json.dumps(output_json) + "\n")
        sys.stdout.flush()
        
        now = datetime.datetime.now()
        time_to_prayer = (next_time - now).total_seconds()
        
        # Execution frame check matching our 30 second automation target windows
        if 0 <= time_to_prayer <= 30 and last_prayer_triggered != output_json["next_name"]:
            last_prayer_triggered = output_json["next_name"]
            
            # 1. Trigger open window structure via subprocess execution layers
            subprocess.Popen(["eww", "-c", str(EWW_DIR), "open", "prayer-tooltip-window"])
            
            # 2. Execute audio asset engine framework cleanly
            playback = subprocess.Popen(["mpv", "--no-video", ADHAN_AUDIO_PATH])
            ADHAN_PID_FILE.write_text(str(playback.pid))
            try:
                playback.wait()
            finally:
                ADHAN_PID_FILE.unlink(missing_ok=True)
            
            # 3. Post playback checklist sequence execution
            subprocess.run(["eww", "-c", str(EWW_DIR), "close", "prayer-tooltip-window"])
            
        time.sleep(10)

if __name__ == "__main__":
    main()
