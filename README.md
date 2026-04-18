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
curl -fsSL https://raw.githubusercontent.com/skosari/killport-win/main/install.bat -o "%TEMP%\kp-install.bat" && "%TEMP%\kp-install.bat"
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
| `killport attack <ip>` | AI pentest: scan 47 common ports + analysis |
| `killport attack allports <ip>` | AI pentest: scan all 65535 ports + analysis |
| `killport attack <ip>:<port>` | AI pentest: single port deep dive |
| `killport attack config` | Configure Ollama host and model |
| `killport attack log` | View attack history |

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
Already up to date (v1.6.7)
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

**Option 1 — built-in command** *(run as Administrator)*

```
killport uninstall
```

**Option 2 — PowerShell** *(elevated — Run as Administrator)*

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/uninstall.ps1 | iex
```

**Option 3 — Command Prompt (CMD)** *(elevated — Run as Administrator)*

```cmd
curl -fsSL https://raw.githubusercontent.com/skosari/killport-win/main/uninstall.ps1 -o "%TEMP%\kp-uninstall.ps1" && powershell -ExecutionPolicy Bypass -File "%TEMP%\kp-uninstall.ps1"
```

Removes the binary, implementation files, and all firewall rules created by `killport open`.

---

## AI Penetration Testing

`killport attack` is an agentic AI-powered pentest tool that uses a locally running [Ollama](https://ollama.com) model to investigate open ports, probe for weak credentials, check for sensitive paths, and attempt to crack discovered hashes — all from the command line.

### Setup

1. [Install Ollama](https://ollama.com/download) and pull a model:
   ```sh
   ollama pull llama3.2
   ```
2. Configure killport to point at your Ollama instance:
   ```sh
   killport attack config
   ```
   - **This machine:** `localhost:11434` or `127.0.0.1:11434`
   - **Another LAN machine:** `192.168.x.x:11434`
   - **Remote server:** `45.76.x.x:11434` *(port 11434 must be open)*

   The config screen connects to Ollama and lets you pick from your loaded models.

3. Missing tools (`nmap`, `sshpass`, `hashcat`) are detected automatically and offered for install via Chocolatey, winget, or Scoop when you run an attack.

### Commands

```sh
killport attack 192.168.1.10            # scan 47 common ports
killport attack allports 192.168.1.10   # scan all 65535 ports
killport attack 192.168.1.10:6379       # single port deep dive
killport attack config                  # configure Ollama
killport attack log                     # view attack history
```

### How it works

The agent runs a **ReAct loop** — Ollama decides what to investigate next, calls a tool, receives the result, and iterates (up to 20 rounds). Tools available to the agent:

| Tool | What it does |
|---|---|
| `SCAN_PORT` | Deep nmap scan with version detection |
| `BANNER_GRAB` | Raw TCP banner grab, extracts hashes |
| `HTTP_PROBE` | Fetch HTTP/HTTPS response, extract hashes |
| `HTTP_PATHS` | Probe sensitive paths (`/admin`, `/.env`, `/actuator/env`, etc.) |
| `WORDLIST` | Try common credentials across SSH, FTP, Redis, MySQL, PostgreSQL, HTTP |
| `NMAP_SCRIPT` | Run nmap NSE scripts |
| `CRACK_HASH` | Crack MD5/SHA1/SHA256/bcrypt hashes via hashcat or john + rockyou |

### Example output

```
  AI Pentest  →  192.168.1.10  (47 common ports)
  ────────────────────────────────────────────

  Pass 1/2  Scanning 47 common ports on 192.168.1.10...

  ●  22        ssh           OpenSSH 8.9p1
  ●  6379      redis         Redis 7.0.11
  ●  27017     mongodb       MongoDB 6.0

  Agent starting  target: 192.168.1.10  ·  model: llama3.2

  ▶  SCAN_PORT 6379
  ▶  WORDLIST redis 6379
     CRITICAL: Redis has NO password — fully open to anyone
  ▶  REPORT

  ══════════════════════════════════════════════════════════════
    SECURITY REPORT  ·  192.168.1.10  ·  2025-04-17 14:32
    Model: llama3.2
  ══════════════════════════════════════════════════════════════

    PORT 6379 — REDIS
    Risk: 🔴 Critical
    ────────────────────────────────────────────────────────
    ⚠  NO PASSWORD REQUIRED — anyone on the network can connect

    What this means:
      Your Redis database has no password set.
      Anyone on your network can read, modify, or delete all stored data.

    How to fix it:
      1. Set a strong password: add  requirepass YOURPASSWORD  to redis.conf
      2. Bind Redis to localhost only: add  bind 127.0.0.1  to redis.conf
      3. Block port 6379 from the network with a firewall rule

  ══════════════════════════════════════════════════════════════
  ── What to do first ──
  ══════════════════════════════════════════════════════════════
    1. [CRITICAL] Set a password on redis (port 6379) — it has none right now
```

---

## Notes

**Firewall rules** — `killport open` and `killport close` manage Windows Firewall inbound rules. Run as Administrator for firewall commands.

---

<div align="center">

Made by [skosari](https://github.com/skosari) · [killport-mac](https://github.com/skosari/killport-mac) · [killport-win](https://github.com/skosari/killport-win) · [killport-linux](https://github.com/skosari/killport-linux)

</div>
