# killport-win

Kill whatever is running on a port. Windows.

Works in both **PowerShell** and **Command Prompt (CMD)**.

```
killport 8080
# Port 8080 is in use:
#
#   PID:   12345
#   Name:  node
#   Addr:  0.0.0.0:8080
#
# Killed.
```

---

## Install

### Option 1 — PowerShell installer (installs both .ps1 and .bat)

Run in an **elevated PowerShell** (Run as Administrator):

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/install.ps1 | iex
```

This installs both `killport.ps1` (PowerShell) and `killport.bat` (CMD) to your PATH.

### Option 2 — CMD only (no PowerShell required)

Run in an **elevated Command Prompt** (Run as Administrator):

```cmd
curl -fsSL https://raw.githubusercontent.com/skosari/killport-win/main/killport.bat -o "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\killport.bat"
```

> Requires Windows 10 or later (curl is built in).

---

## Usage

```
killport <port>     kill whatever is on that port
killport list       list all listening ports
killport update     update to the latest version
```

### killport list

```
killport list
# Listening ports:
#
#   0.0.0.0:3000     node        1234
#   0.0.0.0:5432     postgres    5678
#   127.0.0.1:8080   python      9101
```

---

> **PowerShell execution policy:** If you get a policy error, run:
> ```powershell
> Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
