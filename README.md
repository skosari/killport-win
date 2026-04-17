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

[![Version](https://img.shields.io/badge/version-1.6.7-00b4d8?style=flat-square)](#)
[![Platform](https://img.shields.io/badge/platform-Windows-00b4d8?style=flat-square&logo=windows&logoColor=white)](#)
[![Shell](https://img.shields.io/badge/shell-PowerShell%20%2F%20CMD-00b4d8?style=flat-square&logo=powershell&logoColor=white)](#)
[![License](https://img.shields.io/badge/license-MIT-00b4d8?style=flat-square)](#)

</div>

---

## Install

**Option 1 — PowerShell** *(elevated — Run as Administrator)*

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/install.ps1 | iex
```

**Option 2 — Command Prompt (CMD)** *(elevated — Run as Administrator)*

```cmd
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/skosari/killport-win/main/install.ps1 | iex"
```

Installs `killport.bat` to `System32` (always in PATH for CMD and PowerShell) and the implementation to `C:\ProgramData\killport\`.

> Requires Windows 10 or later.

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
| `killport status <port>` | Show if a port is open or closed |
| `killport ip` | Show IP addresses, DNS, and network info |
| `killport update` | Update to the latest version |
| `killport uninstall` | Remove killport and all firewall rules |

---

## Examples

### `killport 3000`
```
  Port 3000 is in use:

  PID:   48291
  Name:  node
  Addr:  0.0.0.0:3000

Killed.
```

### `killport list`
```
  Listening Ports
  ────────────────────────────────────────────

  ●  0.0.0.0:3000               node
  ●  0.0.0.0:5432               postgres
  ●  0.0.0.0:8080               nginx
  ●  127.0.0.1:6379             redis-server
```

### `killport open 8080`
```
Opening port 8080 to external connections...
Port 8080 is now open (TCP + UDP).
```

### `killport close 8080`
```
Closing port 8080 from external connections...
Port 8080 is now closed.
```

### `killport openports`
```
  Firewall-Open Ports  (external access via killport)
  ────────────────────────────────────────────

  ●  80        listening   nginx
  ●  443       listening   nginx
  ○  8080      not listening

  ────────────────────────────────────────────
  3 port(s) open  ·  2 listening
```

### `killport closedports`
```
  Locally-Listening Ports  (no external access)
  ────────────────────────────────────────────

  ◆  3000      local only   node
  ◆  5432      local only   postgres
  ◆  6379      local only   redis-server

  ────────────────────────────────────────────
  3 port(s) listening locally  ·  no external access
```

### `killport status 3000`
```
  Port 3000 status:

  Firewall:  CLOSED  (no killport rule — external access blocked)
  Listening: YES  (PID: 48291 — node)
```

### `killport ip`
```
  Network Addresses
  ────────────────────────────────────────────

  ┌────────────────────────────────────────
  │  Ethernet  (Realtek Gaming 2.5GbE Family Controller)
  │  IPv4:  192.168.1.42
  │  MAC:   10-FF-E0-23-9B-44
  └────────────────────────────────────────

  Default Gateway
  ────────────────────────────────────
  192.168.1.1

  DNS Servers
  ────────────────────────────────────
  8.8.8.8  (Ethernet)
  8.8.4.4  (Ethernet)

  Firewall-managed ports (killport)
  ────────────────────────────────────
  None
```

### `killport update`
```
Checking for updates...
Already up to date (v1.6.6)
```

### `killport uninstall`
```
Uninstalling killport...
  Removed 4 firewall rule(s)
  Removed C:\Windows\System32\killport.bat
  Removed C:\ProgramData\killport
killport uninstalled.
```

---

## Uninstall

Run in an **elevated PowerShell** (Run as Administrator):

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/uninstall.ps1 | iex
```

Removes the binary, implementation files, and all firewall rules created by `killport open`.

---

## Notes

**Firewall rules** — `killport open` and `killport close` manage Windows Firewall inbound rules. Run as Administrator for firewall commands.

---

<div align="center">

Made by [skosari](https://github.com/skosari) · [killport-mac](https://github.com/skosari/killport-mac) · [killport-win](https://github.com/skosari/killport-win) · [killport-linux](https://github.com/skosari/killport-linux)

</div>
