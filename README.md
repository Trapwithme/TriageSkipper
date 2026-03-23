# TriageSkipper

TriageSkipper is a **multi-language reference repo** for a Windows-focused VM detection routine based on:

- WMI hardware identity checks (keyboard, mouse, input device, monitor, CPU), and
- a wallpaper base64-prefix signature check.

## Repository Layout

```text
.
├── README.md
└── ports
    ├── csharp
    │   └── main.cs
    ├── cpp
    │   └── main.cpp
    ├── go
    │   ├── go.mod
    │   └── main.go
    ├── node
    │   └── main.js
    ├── powershell
    │   └── triageskipper.ps1
    ├── python
    │   └── main.py
    └── rust
        ├── Cargo.toml
        └── src/main.rs
```

## Ports Included

- C# (`ports/csharp/main.cs`)
- C++ (`ports/cpp/main.cpp`)
- Go (`ports/go/main.go`)
- Rust (`ports/rust/src/main.rs`)
- PowerShell (`ports/powershell/triageskipper.ps1`)
- Python (`ports/python/main.py`)
- Node.js (`ports/node/main.js`)

## Running

> These ports are intentionally Windows-oriented. Most rely on WMI/registry APIs and should be run on Windows.

### C#
Compile with your preferred .NET SDK/project setup and run `ports/csharp/main.cs`.

### C++
Compile on Windows with MSVC (WMI + Win32 libraries).

### Go
```bash
go run ./ports/go
```

### Rust
```bash
cd ports/rust
cargo run
```

### PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File .\ports\powershell\triageskipper.ps1
```

### Python
```bash
python ports/python/main.py
```

### Node.js
```bash
node ports/node/main.js
```

## Notes

- The implementation in each language mirrors the same detection logic for parity.
- Exact results can vary by OS version, hardware, and privileges.
- This repo is intended as a code-porting reference and testbed.
