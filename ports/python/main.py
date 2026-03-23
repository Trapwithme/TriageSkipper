#!/usr/bin/env python3
"""Windows VM triage detector (Python port)."""

from __future__ import annotations

import base64
import pathlib
import subprocess
from winreg import HKEY_CURRENT_USER, OpenKey, QueryValueEx

MOUSE_ID = r"ACPI\PNP0F13\4&22F5829E&0"
MOUSE_NAME = "PS2/2 Compatible Mouse"
INPUT_ID = r"USB\VID_0627&PID_0001\28754-0000:00:04.0-1"
INPUT_NAME = "USB Input Device"
MONITOR_ID = r"DISPLAY\RHT1234\4&22F5829E&0"
MONITOR_NAME = "Generic PnP Monitor"
KEYBOARD_ID = r"ACPI\PNP0303\4&22F5829E&0"
KEYBOARD_NAME = "Standard PS/2 Keyboard"
CPU_NAME = "Intel Core Processor (Broadwell)"
WALLPAPER_SIG = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd"


def _contains_ci(haystack: str, needle: str) -> bool:
    return needle.lower() in haystack.lower()


def _wmic(path: str, fields: str) -> list[str]:
    try:
        out = subprocess.check_output(
            ["wmic", "path", path, "get", fields, "/format:csv"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return []

    rows: list[str] = []
    for line in out.splitlines():
        line = line.strip()
        if line and not line.startswith("Node,"):
            rows.append(line)
    return rows


def _parse_csv(line: str) -> list[str]:
    parts = line.split(",")
    return parts[1:] if len(parts) > 1 else []


def _check(path: str, fields: str, id_idx: int, desc_idx: int | None, id_needle: str, desc_needle: str | None) -> int:
    idx = 0
    for row in _wmic(path, fields):
        values = _parse_csv(row)
        if len(values) <= id_idx:
            continue

        device_id = values[id_idx]
        description = values[desc_idx] if desc_idx is not None and len(values) > desc_idx else ""

        if device_id and _contains_ci(device_id, id_needle):
            idx += 1
            if desc_needle and description and _contains_ci(description, desc_needle):
                idx += 1
    return idx


def triage() -> bool:
    total = 0
    total += _check("Win32_Keyboard", "Description,DeviceID", 1, 0, KEYBOARD_ID, KEYBOARD_NAME)
    total += _check("Win32_PointingDevice", "Description,PNPDeviceID", 1, 0, MOUSE_ID, MOUSE_NAME)
    total += _check("Win32_PointingDevice", "Description,PNPDeviceID", 1, 0, INPUT_ID, INPUT_NAME)
    total += _check("Win32_DesktopMonitor", "Description,PNPDeviceID", 1, 0, MONITOR_ID, MONITOR_NAME)
    total += _check("Win32_Processor", "Name", 0, None, CPU_NAME, None)
    return total >= 5


def get_wallpaper() -> str:
    try:
        with OpenKey(HKEY_CURRENT_USER, r"Control Panel\Desktop") as key:
            value, _ = QueryValueEx(key, "Wallpaper")
            return str(value)
    except Exception:
        return ""


def triage_v2() -> bool:
    wallpaper = get_wallpaper().strip()
    if not wallpaper:
        return False

    path = pathlib.Path(wallpaper)
    if not path.exists() or not path.is_file():
        return False

    try:
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    except Exception:
        return False

    return encoded[:64] == WALLPAPER_SIG


def main() -> int:
    print("Running VM detection...")
    if triage() or triage_v2():
        print("Virtual Machine Detected")
        return 1

    print("No VM detected, application can proceed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
