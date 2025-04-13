# TriageSkipper

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/Trapwithme/TriageSkipper)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![C#](https://img.shields.io/badge/language-C%23-blue.svg)](https://docs.microsoft.com/dotnet/csharp/)

A lightweight C# console application designed to detect virtual machine (VM) environments on Windows. It performs hardware checks (keyboard, mouse, monitor, CPU) and wallpaper analysis, displaying a warning and exiting if a VM is detected. Built with Visual Studio, it’s ideal for developers exploring system environment validation.

## Table of Contents
- [Features](#features)

## Features
- **Hardware Detection**: Queries WMI for keyboard, mouse, input devices, monitor, and CPU properties to identify VM-specific signatures.
- **Wallpaper Validation**: Analyzes the desktop wallpaper’s Base64-encoded prefix for VM indicators.
- **User Feedback**: Shows a "Virtual Machine Detected" message box and exits if a VM is found.
- **Robust Error Handling**: Handles null values and WMI failures silently to prevent crashes.
- **Cross-Platform Compatibility**: Supports .NET Core 6.0 and .NET Framework 4.8.
- **Single-File Design**: All logic in `Program.cs` for simplicity and easy modification.

