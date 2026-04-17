<div align="center">

<pre>
██╗  ██╗██╗██╗     ██╗     ██████╗  ██████╗ ██████╗ ████████╗
██║ ██╔╝██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
█████╔╝ ██║██║     ██║     ██████╔╝██║   ██║██████╔╝   ██║   
██╔═██╗ ██║██║     ██║     ██╔═══╝ ██║   ██║██╔══██╗   ██║   
██║  ██╗██║███████╗███████╗██║     ╚██████╔╝██║  ██╗   ██║   
╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
</pre>

**Kill whatever is running on a port — Windows**

[![Version](https://img.shields.io/badge/version-1.6.6-00b4d8?style=flat-square)](#)
[![Platform](https://img.shields.io/badge/platform-Windows-00b4d8?style=flat-square&logo=windows&logoColor=white)](#)
[![Shell](https://img.shields.io/badge/shell-PowerShell%20%2F%20CMD-00b4d8?style=flat-square&logo=powershell&logoColor=white)](#)
[![License](https://img.shields.io/badge/license-MIT-00b4d8?style=flat-square)](#)

</div>

---

```
> killport 3000

Port 3000 is in use:

  PID:   48291
  Name:  node
  Addr:  0.0.0.0:3000

Killed.
```

---

## Install

**Option 1 — PowerShell installer** *(recommended)*

Run in an **elevated PowerShell** (Run as Administrator):

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/install.ps1 | iex
```

Installs both `killport.ps1` (PowerShell) and `killport.bat` (CMD) to your PATH.

**Option 2 — CMD only** *(no PowerShell required)*

Run in an **elevated Command Prompt** (Run as Administrator):

```cmd
curl -fsSL https://raw.githubusercontent.com/skosari/killport-win/main/killport.bat ^
  -o "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\killport.bat"
```

> Requires Windows 10 or later (curl is built in).

---

## Commands

| Command | Description |
|---|---|
| `killport` | Show help |
| `killport <port>` | Kill whatever is running on that port |
| `killport list` | List all listening ports |
| `killport open <port>` | Open a port through Windows Firewall |
| `killport close <port>` | Close a port from external connections |
| `killport openports` | Show all ports open to external access |
| `killport closedports` | Show all listening ports with no external access |
| `killport ports` | Inspect all ports with live firewall status |
| `killport opencheck <ip>` | Probe an IP to verify external reachability |
| `killport status <port>` | Show if a port is open or closed |
| `killport ip` | Show IP addresses, DNS, and network info |
| `killport update` | Update to the latest version |

---

## Notes

**PowerShell execution policy** — if you get a policy error, run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Firewall rules** — `killport open` and `killport close` manage Windows Firewall inbound rules. Run as Administrator for firewall commands.

---

## Update

```powershell
killport update
```

Self-updates by pulling the latest script from this repo. Version is checked via the GitHub API — no CDN caching issues.

---

<div align="center">

Made by [skosari](https://github.com/skosari) · [killport-mac](https://github.com/skosari/killport-mac) · [killport-win](https://github.com/skosari/killport-win) · [killport-linux](https://github.com/skosari/killport-linux)

</div>
