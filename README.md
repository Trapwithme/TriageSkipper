# TriageSkipper

TriageSkipper is a Windows-focused virtual machine detection project that now includes four implementations of the same detection strategy:

- C# (`program.cs`)
- PowerShell (`triageskipper.ps1`)
- Rust (`ports/rust`)
- Go (`ports/go`)
- C++ (`ports/cpp`)

## Detection Method (shared across ports)

Each version keeps the same core behavior:

1. Query hardware via WMI and score matches for VM-like signatures.
2. Check keyboard, mouse, input device, monitor, and CPU strings.
3. Read the current wallpaper path from registry.
4. Read wallpaper bytes, Base64-encode them, and compare the first 64 chars to a fixed signature.
5. Show **"Virtual Machine Detected"** and exit with status code `1` if either hardware triage or wallpaper triage is positive.

## Repository Layout

- `program.cs` — original C# implementation.
- `triageskipper.ps1` — PowerShell port.
- `ports/rust/Cargo.toml` + `ports/rust/src/main.rs` — Rust port.
- `ports/go/go.mod` + `ports/go/main.go` — Go port.
- `ports/cpp/main.cpp` — C++ port.

## Run / Build

> All ports target Windows because they rely on WMI, Windows registry, and Win32 UI APIs.

### C#
Use your existing Visual Studio / .NET setup for `program.cs`.

### PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File .\triageskipper.ps1
```

### Rust
```powershell
cd ports\rust
cargo run --release
```

### Go
```powershell
cd ports\go
go run .
```

### C++ (MSVC Developer Command Prompt)
```bat
cd ports\cpp
cl /EHsc main.cpp /link wbemuuid.lib
main.exe
```

## Notes

- The implementations intentionally preserve silent error handling in detection helpers to match the original behavior.
- Threshold and signatures are kept equivalent to the original logic so outcomes stay consistent across languages.
