# killport-win

Kill whatever is running on a port. Windows.

```powershell
killport 8080
# Port 8080 is in use:
#
#   PID:     12345
#   Name:    node
#   Path:    C:\Program Files\nodejs\node.exe
#
# Killed.
```

---

## Install

### Option 1 — PowerShell (one-liner)

Run this in an **elevated PowerShell** (Run as Administrator):

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/install.ps1 | iex
```

This installs `killport.ps1` and a `killport.cmd` wrapper so you can use it from any terminal (PowerShell, CMD, Windows Terminal).

### Option 2 — Manual

1. Download the script:
   ```powershell
   Invoke-WebRequest -Uri https://raw.githubusercontent.com/skosari/killport-win/main/killport.ps1 -OutFile killport.ps1
   ```
2. Move it somewhere on your `$PATH` (e.g. `C:\Windows\System32\` or a custom bin folder)
3. Run it:
   ```powershell
   powershell -ExecutionPolicy Bypass -File killport.ps1 8080
   ```

---

## Usage

```powershell
killport <port>     # kill whatever is on that port
killport list       # list all listening ports
```

### killport list

```powershell
killport list
# Listening ports:
#
#   0.0.0.0:3000              node       1234
#   0.0.0.0:5432              postgres   5678
#   127.0.0.1:8080            python     9101
```

> **Note:** If you get an execution policy error, run PowerShell as Administrator and execute:
> ```powershell
> Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
