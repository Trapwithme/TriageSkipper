#!/usr/bin/env node

/* Windows VM triage detector (Node.js port). */

const fs = require('fs');
const cp = require('child_process');

const MOUSE_ID = String.raw`ACPI\PNP0F13\4&22F5829E&0`;
const MOUSE_NAME = 'PS2/2 Compatible Mouse';
const INPUT_ID = String.raw`USB\VID_0627&PID_0001\28754-0000:00:04.0-1`;
const INPUT_NAME = 'USB Input Device';
const MONITOR_ID = String.raw`DISPLAY\RHT1234\4&22F5829E&0`;
const MONITOR_NAME = 'Generic PnP Monitor';
const KEYBOARD_ID = String.raw`ACPI\PNP0303\4&22F5829E&0`;
const KEYBOARD_NAME = 'Standard PS/2 Keyboard';
const CPU_NAME = 'Intel Core Processor (Broadwell)';
const WALLPAPER_SIG = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd';

const ciContains = (haystack, needle) => haystack.toLowerCase().includes(needle.toLowerCase());

function runWmic(path, fields) {
  try {
    const out = cp.execFileSync('wmic', ['path', path, 'get', fields, '/format:csv'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return out
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('Node,'));
  } catch {
    return [];
  }
}

function parseCsv(line) {
  const parts = line.split(',');
  return parts.length > 1 ? parts.slice(1) : [];
}

function check(path, fields, idIndex, descIndex, idNeedle, descNeedle) {
  let idx = 0;
  for (const line of runWmic(path, fields)) {
    const vals = parseCsv(line);
    if (vals.length <= idIndex) continue;

    const id = vals[idIndex] || '';
    const desc = descIndex !== null && vals.length > descIndex ? vals[descIndex] : '';

    if (id && ciContains(id, idNeedle)) {
      idx += 1;
      if (descNeedle && desc && ciContains(desc, descNeedle)) {
        idx += 1;
      }
    }
  }
  return idx;
}

function triage() {
  let total = 0;
  total += check('Win32_Keyboard', 'Description,DeviceID', 1, 0, KEYBOARD_ID, KEYBOARD_NAME);
  total += check('Win32_PointingDevice', 'Description,PNPDeviceID', 1, 0, MOUSE_ID, MOUSE_NAME);
  total += check('Win32_PointingDevice', 'Description,PNPDeviceID', 1, 0, INPUT_ID, INPUT_NAME);
  total += check('Win32_DesktopMonitor', 'Description,PNPDeviceID', 1, 0, MONITOR_ID, MONITOR_NAME);
  total += check('Win32_Processor', 'Name', 0, null, CPU_NAME, null);
  return total >= 5;
}

function getWallpaper() {
  try {
    const out = cp.execFileSync('reg', ['query', 'HKCU\\Control Panel\\Desktop', '/v', 'Wallpaper'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });

    const line = out
      .split(/\r?\n/)
      .map((l) => l.trim())
      .find((l) => /^Wallpaper\s+/i.test(l));

    if (!line) return '';
    return line.split(/\s+/).slice(2).join(' ');
  } catch {
    return '';
  }
}

function triageV2() {
  const wallpaper = getWallpaper().trim();
  if (!wallpaper || !fs.existsSync(wallpaper)) return false;

  try {
    const b64 = fs.readFileSync(wallpaper).toString('base64');
    return b64.slice(0, 64) === WALLPAPER_SIG;
  } catch {
    return false;
  }
}

function main() {
  console.log('Running VM detection...');
  if (triage() || triageV2()) {
    console.log('Virtual Machine Detected');
    process.exit(1);
  }
  console.log('No VM detected, application can proceed.');
}

main();
