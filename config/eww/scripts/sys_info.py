#!/usr/bin/env python3
"""
sys_info.py — System info tanpa blocking sleep
Simpan /proc/stat sebelumnya di file cache, diff saat dipanggil berikutnya.
"""

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CACHE_FILE = Path("/tmp/eww_cpu_stat_cache")

# ─── CPU Usage ────────────────────────────────────────────────────────────────


def read_proc_stat() -> tuple[int, int]:
    """Return (total, idle) dari /proc/stat baris cpu."""
    line = Path("/proc/stat").read_text().splitlines()[0]
    fields = line.split()[1:]  # skip label "cpu"
    vals = [int(f) for f in fields]
    total = sum(vals)
    idle = vals[3]  # index 3 = idle
    return total, idle


def get_cpu_usage() -> int:
    total2, idle2 = read_proc_stat()

    if CACHE_FILE.exists():
        try:
            total1, idle1 = map(int, CACHE_FILE.read_text().split())
            diff_total = total2 - total1
            diff_idle = idle2 - idle1
            usage = (
                int(100 * (diff_total - diff_idle) / diff_total)
                if diff_total > 0
                else 0
            )
        except (ValueError, ZeroDivisionError):
            usage = 0
    else:
        usage = 0

    # Simpan state sekarang untuk pemanggilan berikutnya
    CACHE_FILE.write_text(f"{total2} {idle2}")
    return usage


# ─── CPU Temp ─────────────────────────────────────────────────────────────────


def get_cpu_temp() -> int:
    # Metode 1: hwmon label
    for input_file in Path("/sys/class/hwmon").glob("hwmon*/temp*_input"):
        label_file = Path(str(input_file).replace("_input", "_label"))
        if not label_file.exists():
            continue
        label = label_file.read_text().strip()
        if re.match(r"^(Package id|Core 0|Tctl|Tccd)", label):
            try:
                val = int(input_file.read_text())
                if val > 0:
                    return val // 1000
            except (ValueError, OSError):
                continue

    # Metode 2: thermal_zone
    for zone in Path("/sys/class/thermal").glob("thermal_zone*"):
        try:
            zone_type = (zone / "type").read_text().strip()
            if zone_type in ("x86_pkg_temp", "cpu-thermal", "cpu_thermal"):
                val = int((zone / "temp").read_text())
                if val > 0:
                    return val // 1000 if val > 1000 else val
        except (ValueError, OSError):
            continue

    return 0


# ─── CPU name ─────────────────────────────────────────────────────────────────


def get_cpu_name() -> str:
    """e.g. "AMD Ryzen 7 7700X" (marketing suffixes trimmed)."""
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1]
            name = re.sub(r"\((R|TM|tm)\)|\bCPU\b|@.*$|\d+-Core Processor|Processor", "", name)
            return " ".join(name.split())
    return ""


# ─── RAM ──────────────────────────────────────────────────────────────────────


def get_mem() -> dict:
    info = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, *rest = line.split()
        info[key.rstrip(":")] = int(rest[0])

    total_kb = info.get("MemTotal", 0)
    available_kb = info.get("MemAvailable", 0)
    used_kb = total_kb - available_kb

    def fmt(kb: int) -> str:
        if kb >= 1048576:
            return f"{kb/1048576:.1f}G"
        return f"{kb/1024:.0f}M"

    perc = int(100 * used_kb / total_kb) if total_kb > 0 else 0
    return {
        "mem_perc": perc,
        "mem_used": fmt(used_kb),
        "mem_total": fmt(total_kb),
    }


# ─── Disk ─────────────────────────────────────────────────────────────────────


def get_disk() -> dict:
    st = os.statvfs("/")
    total = st.f_blocks * st.f_frsize
    free = st.f_bfree * st.f_frsize
    used = total - free
    perc = int(100 * used / total) if total > 0 else 0

    def fmt(b: int) -> str:
        if b >= 1_073_741_824:
            return f"{b/1_073_741_824:.1f}G"
        return f"{b/1_048_576:.0f}M"

    return {
        "disk_perc": perc,
        "disk_used": fmt(used),
        "disk_total": fmt(total),
    }


# ─── GPU ──────────────────────────────────────────────────────────────────────
# The main graphics card: NVIDIA through nvidia-smi, AMD (and Intel, partly)
# through sysfs. With two cards (e.g. a Ryzen iGPU + a Radeon), the one with
# the most video memory wins. Fields are null when the driver doesn't say.


def _read(path: Path):
    try:
        return path.read_text().strip()
    except OSError:
        return None


def _gb(b: int) -> str:
    return f"{b / 1_073_741_824:.1f}G"


def _gpu_name(dev: Path) -> str:
    """Short card name from lspci, cached (it never changes). When lspci
    lists several models for the chip ("RX 6700/6700 XT/..."), use the chip
    name instead of guessing which one it is."""
    slot = dev.resolve().name
    cache = Path(f"/tmp/eww_gpu_name_{slot}")
    if cache.exists():
        return cache.read_text()
    name = ""
    try:
        out = subprocess.run(["lspci", "-mm", "-s", slot], capture_output=True,
                             text=True, timeout=2).stdout
        fields = re.findall(r'"([^"]*)"', out)
        vendor, device = fields[1], fields[2]
        vendor = "AMD" if "AMD" in vendor or "ATI" in vendor else vendor.split()[0]
        m = re.match(r"(.*?)\s*\[(.*)\]", device)
        if m and "/" not in m.group(2):
            name = m.group(2)
        elif m:
            name = f"{vendor} {m.group(1)}"
        else:
            name = f"{vendor} {device}"
    except (OSError, IndexError, subprocess.SubprocessError):
        pass
    cache.write_text(name)
    return name


def get_gpu() -> dict:
    empty = {"gpu_present": False, "gpu_name": "", "gpu_usage": None, "gpu_temp": None,
             "gpu_vram_perc": None, "gpu_vram_used": "", "gpu_vram_total": ""}

    if shutil.which("nvidia-smi"):
        try:
            out = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=2).stdout.splitlines()
            name, *nums = (x.strip() for x in out[0].split(","))
            usage, temp, used, total = (int(float(x)) for x in nums)
            return {"gpu_present": True, "gpu_name": name.replace("NVIDIA GeForce ", "GeForce "), "gpu_usage": usage, "gpu_temp": temp,
                    "gpu_vram_perc": int(100 * used / total) if total else None,
                    "gpu_vram_used": _gb(used * 1_048_576), "gpu_vram_total": _gb(total * 1_048_576)}
        except (OSError, ValueError, IndexError, subprocess.SubprocessError):
            pass

    best, best_vram = None, -1
    for card in Path("/sys/class/drm").glob("card*"):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        dev = card / "device"
        vram = _read(dev / "mem_info_vram_total")
        vram = int(vram) if vram and vram.isdigit() else 0
        if vram > best_vram:
            best, best_vram = dev, vram
    if best is None:
        return empty

    busy = _read(best / "gpu_busy_percent")
    used = _read(best / "mem_info_vram_used")
    temp = None
    for t in sorted(best.glob("hwmon/hwmon*/temp*_input")):
        label = _read(t.with_name(t.name.replace("_input", "_label"))) or ""
        if label in ("edge", "") or temp is None:
            val = _read(t)
            if val and val.lstrip("-").isdigit():
                temp = int(val) // 1000
            if label == "edge":
                break
    used = int(used) if used and used.isdigit() else None
    return {
        "gpu_present": True,
        "gpu_name": _gpu_name(best),
        "gpu_usage": int(busy) if busy and busy.isdigit() else None,
        "gpu_temp": temp,
        "gpu_vram_perc": int(100 * used / best_vram) if used is not None and best_vram else None,
        "gpu_vram_used": _gb(used) if used is not None else "",
        "gpu_vram_total": _gb(best_vram) if best_vram else "",
    }


# ─── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    result = {
        "cpu_usage": get_cpu_usage(),
        "cpu_temp": get_cpu_temp(),
        "cpu_name": get_cpu_name(),
        **get_mem(),
        **get_disk(),
        **get_gpu(),
    }
    print(json.dumps(result, ensure_ascii=False))
