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
$WallpaperSignature = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd'

function Contains-IgnoreCase {
    param(
        [string]$Value,
        [string]$Needle
    )

    return -not [string]::IsNullOrEmpty($Value) -and $Value.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Invoke-WmiQuery {
    param([string]$Query)

    try {
        $searcher = New-Object System.Management.ManagementObjectSearcher($Query)
        return $searcher.Get()
    }
    catch {
        # Silent error handling
        return @()
    }
}

function Check-Keyboard {
    $index = 0

    foreach ($obj in (Invoke-WmiQuery 'SELECT Description, DeviceID FROM Win32_Keyboard')) {
        $description = [string]($obj['Description'])
        $deviceId = [string]($obj['DeviceID'])

        if (Contains-IgnoreCase -Value $deviceId -Needle $KeyboardID) {
            $index++

            if (Contains-IgnoreCase -Value $description -Needle $KeyboardName) {
                $index++
            }
        }
    }

    return @($index -ge 1, $index)
}

function Check-Mouse {
    $index = 0

    foreach ($obj in (Invoke-WmiQuery 'SELECT Description, PNPDeviceID FROM Win32_PointingDevice')) {
        $description = [string]($obj['Description'])
        $pnpDeviceId = [string]($obj['PNPDeviceID'])

        if (Contains-IgnoreCase -Value $pnpDeviceId -Needle $MouseID) {
            $index++

            if (Contains-IgnoreCase -Value $description -Needle $MouseName) {
                $index++
            }
        }
    }

    return @($index -ge 1, $index)
}

function Check-Input {
    $index = 0

    foreach ($obj in (Invoke-WmiQuery 'SELECT Description, PNPDeviceID FROM Win32_PointingDevice')) {
        $description = [string]($obj['Description'])
        $pnpDeviceId = [string]($obj['PNPDeviceID'])

        if (Contains-IgnoreCase -Value $pnpDeviceId -Needle $InputID) {
            $index++

            if (Contains-IgnoreCase -Value $description -Needle $InputName) {
                $index++
            }
        }
    }

    return @($index -ge 1, $index)
}

function Check-Monitor {
    $index = 0

    foreach ($obj in (Invoke-WmiQuery 'SELECT Description, PNPDeviceID FROM Win32_DesktopMonitor')) {
        $description = [string]($obj['Description'])
        $pnpDeviceId = [string]($obj['PNPDeviceID'])

        if (Contains-IgnoreCase -Value $pnpDeviceId -Needle $MonitorID) {
            $index++

            if (Contains-IgnoreCase -Value $description -Needle $MonitorName) {
                $index++
            }
        }
    }

    return @($index -ge 1, $index)
}

function Check-CPU {
    $index = 0

    foreach ($obj in (Invoke-WmiQuery 'SELECT Name FROM Win32_Processor')) {
        $name = [string]($obj['Name'])

        if (Contains-IgnoreCase -Value $name -Needle $CPU) {
            $index++
        }
    }

    return @($index -ge 1, $index)
}

function Get-Wallpaper {
    try {
        return [string]((Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction Stop).Wallpaper)
    }
    catch {
        # Silent error handling
    }

    return ''
}

function Encode-ToBase64 {
    param([byte[]]$Data)

    try {
        return [System.Convert]::ToBase64String($Data)
    }
    catch {
        # Silent error handling
    }

    return ''
}

function Read-Image {
    param([string]$FilePath)

    try {
        return [System.IO.File]::ReadAllBytes($FilePath)
    }
    catch {
        # Silent error handling
    }

    return @()
}

function Truncate-Base64 {
    param([string]$Base64String)

    return ($Base64String.Length -gt 64) ? $Base64String.Substring(0, 64) : $Base64String
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

        return $truncatedBase64 -eq $WallpaperSignature
    }
    catch {
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
}
catch {
    Write-Host ("Error: {0}" -f $_.Exception.Message)
}
