use base64::{engine::general_purpose, Engine as _};
use serde::Deserialize;
use std::fs;
use windows::core::PCWSTR;
use windows::Win32::UI::WindowsAndMessaging::{MessageBoxW, MB_ICONWARNING, MB_OK};
use winreg::enums::*;
use winreg::RegKey;
use wmi::{COMLibrary, WMIConnection};

const MOUSE_ID: &str = r"ACPI\PNP0F13\4&22F5829E&0";
const MOUSE_NAME: &str = "PS2/2 Compatible Mouse";
const INPUT_ID: &str = r"USB\VID_0627&PID_0001\28754-0000:00:04.0-1";
const INPUT_NAME: &str = "USB Input Device";
const MONITOR_ID: &str = r"DISPLAY\RHT1234\4&22F5829E&0";
const MONITOR_NAME: &str = "Generic PnP Monitor";
const KEYBOARD_ID: &str = r"ACPI\PNP0303\4&22F5829E&0";
const KEYBOARD_NAME: &str = "Standard PS/2 Keyboard";
const CPU: &str = "Intel Core Processor (Broadwell)";
const WALLPAPER_SIG: &str = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd";

#[derive(Deserialize)]
struct KeyboardRow {
    #[serde(rename = "Description")]
    description: Option<String>,
    #[serde(rename = "DeviceID")]
    device_id: Option<String>,
}

#[derive(Deserialize)]
struct DeviceRow {
    #[serde(rename = "Description")]
    description: Option<String>,
    #[serde(rename = "PNPDeviceID")]
    pnp_device_id: Option<String>,
}

#[derive(Deserialize)]
struct CpuRow {
    #[serde(rename = "Name")]
    name: Option<String>,
}

fn contains_ci(haystack: &str, needle: &str) -> bool {
    haystack.to_ascii_lowercase().contains(&needle.to_ascii_lowercase())
}

fn check_keyboard(wmi: &WMIConnection) -> (bool, i32) {
    let mut idx = 0;
    if let Ok(rows) = wmi.raw_query::<KeyboardRow>("SELECT Description, DeviceID FROM Win32_Keyboard") {
        for r in rows {
            let desc = r.description.unwrap_or_default();
            let dev = r.device_id.unwrap_or_default();
            if !dev.is_empty() && contains_ci(&dev, KEYBOARD_ID) {
                idx += 1;
                if !desc.is_empty() && contains_ci(&desc, KEYBOARD_NAME) {
                    idx += 1;
                }
            }
        }
    }
    (idx >= 1, idx)
}

fn check_mouse(wmi: &WMIConnection) -> (bool, i32) {
    let mut idx = 0;
    if let Ok(rows) = wmi.raw_query::<DeviceRow>("SELECT Description, PNPDeviceID FROM Win32_PointingDevice") {
        for r in rows {
            let desc = r.description.unwrap_or_default();
            let dev = r.pnp_device_id.unwrap_or_default();
            if !dev.is_empty() && contains_ci(&dev, MOUSE_ID) {
                idx += 1;
                if !desc.is_empty() && contains_ci(&desc, MOUSE_NAME) {
                    idx += 1;
                }
            }
        }
    }
    (idx >= 1, idx)
}

fn check_input(wmi: &WMIConnection) -> (bool, i32) {
    let mut idx = 0;
    if let Ok(rows) = wmi.raw_query::<DeviceRow>("SELECT Description, PNPDeviceID FROM Win32_PointingDevice") {
        for r in rows {
            let desc = r.description.unwrap_or_default();
            let dev = r.pnp_device_id.unwrap_or_default();
            if !dev.is_empty() && contains_ci(&dev, INPUT_ID) {
                idx += 1;
                if !desc.is_empty() && contains_ci(&desc, INPUT_NAME) {
                    idx += 1;
                }
            }
        }
    }
    (idx >= 1, idx)
}

fn check_monitor(wmi: &WMIConnection) -> (bool, i32) {
    let mut idx = 0;
    if let Ok(rows) = wmi.raw_query::<DeviceRow>("SELECT Description, PNPDeviceID FROM Win32_DesktopMonitor") {
        for r in rows {
            let desc = r.description.unwrap_or_default();
            let dev = r.pnp_device_id.unwrap_or_default();
            if !dev.is_empty() && contains_ci(&dev, MONITOR_ID) {
                idx += 1;
                if !desc.is_empty() && contains_ci(&desc, MONITOR_NAME) {
                    idx += 1;
                }
            }
        }
    }
    (idx >= 1, idx)
}

fn check_cpu(wmi: &WMIConnection) -> (bool, i32) {
    let mut idx = 0;
    if let Ok(rows) = wmi.raw_query::<CpuRow>("SELECT Name FROM Win32_Processor") {
        for r in rows {
            let name = r.name.unwrap_or_default();
            if !name.is_empty() && contains_ci(&name, CPU) {
                idx += 1;
            }
        }
    }
    (idx >= 1, idx)
}

fn get_wallpaper() -> String {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    hkcu.open_subkey("Control Panel\\Desktop")
        .ok()
        .and_then(|k| k.get_value::<String, _>("Wallpaper").ok())
        .unwrap_or_default()
}

fn triage(wmi: &WMIConnection) -> bool {
    let checks = [
        check_keyboard(wmi),
        check_mouse(wmi),
        check_input(wmi),
        check_monitor(wmi),
        check_cpu(wmi),
    ];
    checks.iter().map(|(_, idx)| *idx).sum::<i32>() >= 5
}

fn triage_v2() -> bool {
    let wp = get_wallpaper().trim().to_string();
    if wp.is_empty() {
        return false;
    }
    let bytes = match fs::read(wp) {
        Ok(v) => v,
        Err(_) => return false,
    };
    if bytes.is_empty() {
        return false;
    }
    let b64 = general_purpose::STANDARD.encode(bytes);
    let prefix = if b64.len() > 64 { &b64[..64] } else { &b64 };
    prefix == WALLPAPER_SIG
}

fn show_vm_message() {
    let title: Vec<u16> = "System Check\0".encode_utf16().collect();
    let body: Vec<u16> = "Virtual Machine Detected\0".encode_utf16().collect();
    unsafe {
        let _ = MessageBoxW(None, PCWSTR(body.as_ptr()), PCWSTR(title.as_ptr()), MB_OK | MB_ICONWARNING);
    }
}

fn main() {
    println!("Running VM detection...");
    let com = match COMLibrary::new() {
        Ok(v) => v,
        Err(_) => return,
    };
    let wmi = match WMIConnection::new(com.into()) {
        Ok(v) => v,
        Err(_) => return,
    };

    if triage(&wmi) || triage_v2() {
        show_vm_message();
        std::process::exit(1);
    }

    println!("No VM detected, application can proceed.");
}
