//go:build windows

package main

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"unsafe"
)

const (
	mouseID      = `ACPI\PNP0F13\4&22F5829E&0`
	mouseName    = "PS2/2 Compatible Mouse"
	inputID      = `USB\VID_0627&PID_0001\28754-0000:00:04.0-1`
	inputName    = "USB Input Device"
	monitorID    = `DISPLAY\RHT1234\4&22F5829E&0`
	monitorName  = "Generic PnP Monitor"
	keyboardID   = `ACPI\PNP0303\4&22F5829E&0`
	keyboardName = "Standard PS/2 Keyboard"
	cpuName      = "Intel Core Processor (Broadwell)"
	wallpaperSig = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd"
)

func containsCI(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(needle))
}

func runWmic(path, fields string) []string {
	out, err := exec.Command("wmic", "path", path, "get", fields, "/format:csv").Output()
	if err != nil {
		return nil
	}
	lines := []string{}
	s := bufio.NewScanner(strings.NewReader(string(out)))
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line != "" && !strings.HasPrefix(line, "Node,") {
			lines = append(lines, line)
		}
	}
	return lines
}

func parseCsvLine(line string) []string {
	parts := strings.Split(line, ",")
	if len(parts) <= 1 {
		return nil
	}
	return parts[1:] // skip Node
}

func checkKeyboard() (bool, int) {
	idx := 0
	for _, line := range runWmic("Win32_Keyboard", "Description,DeviceID") {
		vals := parseCsvLine(line)
		if len(vals) < 2 {
			continue
		}
		description, deviceID := vals[0], vals[1]
		if deviceID != "" && containsCI(deviceID, keyboardID) {
			idx++
			if description != "" && containsCI(description, keyboardName) {
				idx++
			}
		}
	}
	return idx >= 1, idx
}

func checkMouse() (bool, int) {
	idx := 0
	for _, line := range runWmic("Win32_PointingDevice", "Description,PNPDeviceID") {
		vals := parseCsvLine(line)
		if len(vals) < 2 {
			continue
		}
		description, pnp := vals[0], vals[1]
		if pnp != "" && containsCI(pnp, mouseID) {
			idx++
			if description != "" && containsCI(description, mouseName) {
				idx++
			}
		}
	}
	return idx >= 1, idx
}

func checkInput() (bool, int) {
	idx := 0
	for _, line := range runWmic("Win32_PointingDevice", "Description,PNPDeviceID") {
		vals := parseCsvLine(line)
		if len(vals) < 2 {
			continue
		}
		description, pnp := vals[0], vals[1]
		if pnp != "" && containsCI(pnp, inputID) {
			idx++
			if description != "" && containsCI(description, inputName) {
				idx++
			}
		}
	}
	return idx >= 1, idx
}

func checkMonitor() (bool, int) {
	idx := 0
	for _, line := range runWmic("Win32_DesktopMonitor", "Description,PNPDeviceID") {
		vals := parseCsvLine(line)
		if len(vals) < 2 {
			continue
		}
		description, pnp := vals[0], vals[1]
		if pnp != "" && containsCI(pnp, monitorID) {
			idx++
			if description != "" && containsCI(description, monitorName) {
				idx++
			}
		}
	}
	return idx >= 1, idx
}

func checkCPU() (bool, int) {
	idx := 0
	for _, line := range runWmic("Win32_Processor", "Name") {
		vals := parseCsvLine(line)
		if len(vals) < 1 {
			continue
		}
		if vals[0] != "" && containsCI(vals[0], cpuName) {
			idx++
		}
	}
	return idx >= 1, idx
}

func getWallpaper() string {
	out, err := exec.Command("reg", "query", `HKCU\Control Panel\Desktop`, "/v", "Wallpaper").Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(strings.ToLower(line), "wallpaper") {
			parts := strings.Fields(line)
			if len(parts) >= 3 {
				return strings.Join(parts[2:], " ")
			}
		}
	}
	return ""
}

func triage() bool {
	checks := []func() (bool, int){checkKeyboard, checkMouse, checkInput, checkMonitor, checkCPU}
	total := 0
	for _, fn := range checks {
		_, idx := fn()
		total += idx
	}
	return total >= 5
}

func triageV2() bool {
	wp := strings.TrimSpace(getWallpaper())
	if wp == "" {
		return false
	}
	bytes, err := os.ReadFile(wp)
	if err != nil || len(bytes) == 0 {
		return false
	}
	enc := base64.StdEncoding.EncodeToString(bytes)
	if len(enc) > 64 {
		enc = enc[:64]
	}
	return enc == wallpaperSig
}

func showMessage() {
	user32 := syscall.NewLazyDLL("user32.dll")
	msgBox := user32.NewProc("MessageBoxW")
	text, _ := syscall.UTF16PtrFromString("Virtual Machine Detected")
	title, _ := syscall.UTF16PtrFromString("System Check")
	msgBox.Call(0, uintptr(unsafe.Pointer(text)), uintptr(unsafe.Pointer(title)), uintptr(0x30))
}

func main() {
	fmt.Println("Running VM detection...")
	if triage() || triageV2() {
		showMessage()
		os.Exit(1)
	}
	fmt.Println("No VM detected, application can proceed.")
}
