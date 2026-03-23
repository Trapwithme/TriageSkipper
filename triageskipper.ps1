Add-Type -AssemblyName System.Windows.Forms

$MouseID = 'ACPI\PNP0F13\4&22F5829E&0'
$MouseName = 'PS2/2 Compatible Mouse'

$InputID = 'USB\VID_0627&PID_0001\28754-0000:00:04.0-1'
$InputName = 'USB Input Device'

$MonitorID = 'DISPLAY\RHT1234\4&22F5829E&0'
$MonitorName = 'Generic PnP Monitor'

$KeyboardID = 'ACPI\PNP0303\4&22F5829E&0'
$KeyboardName = 'Standard PS/2 Keyboard'

$CPU = 'Intel Core Processor (Broadwell)'

function Check-Keyboard {
    $index = 0
    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher('SELECT Description, DeviceID FROM Win32_Keyboard')
        foreach ($obj in $searcher.Get()) {
            $description = [string]($obj['Description'])
            $deviceId = [string]($obj['DeviceID'])

            if (![string]::IsNullOrEmpty($deviceId) -and $deviceId.IndexOf($KeyboardID, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $index++
                if (![string]::IsNullOrEmpty($description) -and $description.IndexOf($KeyboardName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $index++
                }
            }
        }
    } catch {
        # Silent error handling
    }

    return @($index -ge 1, $index)
}

function Check-Mouse {
    $index = 0
    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher('SELECT Description, PNPDeviceID FROM Win32_PointingDevice')
        foreach ($obj in $searcher.Get()) {
            $description = [string]($obj['Description'])
            $pnpDeviceId = [string]($obj['PNPDeviceID'])

            if (![string]::IsNullOrEmpty($pnpDeviceId) -and $pnpDeviceId.IndexOf($MouseID, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $index++
                if (![string]::IsNullOrEmpty($description) -and $description.IndexOf($MouseName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $index++
                }
            }
        }
    } catch {
        # Silent error handling
    }

    return @($index -ge 1, $index)
}

function Check-Input {
    $index = 0
    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher('SELECT Description, PNPDeviceID FROM Win32_PointingDevice')
        foreach ($obj in $searcher.Get()) {
            $description = [string]($obj['Description'])
            $pnpDeviceId = [string]($obj['PNPDeviceID'])

            if (![string]::IsNullOrEmpty($pnpDeviceId) -and $pnpDeviceId.IndexOf($InputID, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $index++
                if (![string]::IsNullOrEmpty($description) -and $description.IndexOf($InputName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $index++
                }
            }
        }
    } catch {
        # Silent error handling
    }

    return @($index -ge 1, $index)
}

function Check-Monitor {
    $index = 0
    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher('SELECT Description, PNPDeviceID FROM Win32_DesktopMonitor')
        foreach ($obj in $searcher.Get()) {
            $description = [string]($obj['Description'])
            $pnpDeviceId = [string]($obj['PNPDeviceID'])

            if (![string]::IsNullOrEmpty($pnpDeviceId) -and $pnpDeviceId.IndexOf($MonitorID, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $index++
                if (![string]::IsNullOrEmpty($description) -and $description.IndexOf($MonitorName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $index++
                }
            }
        }
    } catch {
        # Silent error handling
    }

    return @($index -ge 1, $index)
}

function Check-CPU {
    $index = 0
    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher('SELECT Name FROM Win32_Processor')
        foreach ($obj in $searcher.Get()) {
            $name = [string]($obj['Name'])
            if (![string]::IsNullOrEmpty($name) -and $name.IndexOf($CPU, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $index++
            }
        }
    } catch {
        # Silent error handling
    }

    return @($index -ge 1, $index)
}

function Get-Wallpaper {
    try {
        return [string]((Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction Stop).Wallpaper)
    } catch {
        # Silent error handling
    }

    return ''
}

function Encode-ToBase64 {
    param(
        [byte[]]$Data
    )

    try {
        return [System.Convert]::ToBase64String($Data)
    } catch {
        # Silent error handling
    }

    return ''
}

function Read-Image {
    param(
        [string]$FilePath
    )

    try {
        return [System.IO.File]::ReadAllBytes($FilePath)
    } catch {
        # Silent error handling
    }

    return @()
}

function Truncate-Base64 {
    param(
        [string]$Base64String
    )

    if ($Base64String.Length -gt 64) {
        return $Base64String.Substring(0, 64)
    }

    return $Base64String
}

function Triage {
    $checks = @(
        { Check-Keyboard },
        { Check-Mouse },
        { Check-Input },
        { Check-Monitor },
        { Check-CPU }
    )

    $totalIndex = 0
    foreach ($check in $checks) {
        $result = & $check
        $totalIndex += [int]$result[1]
    }

    return $totalIndex -ge 5
}

function TriageV2 {
    try {
        $wallpaperPath = (Get-Wallpaper).Trim()
        if ([string]::IsNullOrEmpty($wallpaperPath)) {
            return $false
        }

        $imageBytes = Read-Image -FilePath $wallpaperPath
        if ($imageBytes.Length -eq 0) {
            return $false
        }

        $base64String = Encode-ToBase64 -Data $imageBytes
        $truncatedBase64 = Truncate-Base64 -Base64String $base64String

        return $truncatedBase64 -eq '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd'
    } catch {
        # Silent error handling
    }

    return $false
}

function Run-Triage {
    $isTriageDetected = Triage
    $isTriageV2Detected = TriageV2

    if ($isTriageDetected -or $isTriageV2Detected) {
        [System.Windows.Forms.MessageBox]::Show(
            'Virtual Machine Detected',
            'System Check',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        exit 1
    }
}

try {
    Write-Host 'Running VM detection...'
    Run-Triage
    Write-Host 'No VM detected, application can proceed.'
} catch {
    Write-Host ("Error: {0}" -f $_.Exception.Message)
}
