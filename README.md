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

### `killport attack config`
```
  Attack Config
  ────────────────────────────────────────────

  Config: C:\Users\Sam\.config\killport\attack.conf

  Ollama Host
  Ollama is the AI engine that runs your models locally or on another machine.

    • This machine:    localhost:11434  or  127.0.0.1:11434
    • Another LAN box: 192.168.x.x:11434  (the IP of that machine)
    • Remote server:   45.76.x.x:11434   (must have port 11434 open)

  Default port is always 11434. Press Enter to keep current value.

  Current: localhost:11434
  → 

  Connecting to Ollama at localhost:11434...
  Connected.  2 model(s) available:

  ▶  1  llama3.2:latest
     2  deepseek-r1:8b

  Select model  [current: 1]
  → 2

  Saved.  Host: localhost:11434  ·  Model: deepseek-r1:8b
```

### `killport attack 192.168.1.10`
```
  AI Pentest  →  192.168.1.10  (47 common ports)
  ────────────────────────────────────────────

  nmap not installed — needed for port/service scanning.
  Install nmap now via Chocolatey? [Y/n] → y

  ... (choco install nmap -y) ...

  Connecting to Ollama at localhost:11434...
  Model: deepseek-r1:8b

  Scanning 47 common ports on 192.168.1.10...

  ●  22        ssh           OpenSSH 8.9p1
  ●  80        http          Apache httpd 2.4.52
  ●  6379      redis         Redis key-value store

  Agent starting  target: 192.168.1.10  ·  model: deepseek-r1:8b

  ▶  SCAN_PORT 6379
  ▶  WORDLIST redis 6379
     CRITICAL: Redis has NO password — fully open to anyone
  ▶  HTTP_PATHS 80
     200  /admin
     200  /.env
  ▶  REPORT

  Building report...

  ══════════════════════════════════════════════════════════════
    SECURITY REPORT  ·  192.168.1.10  ·  2025-04-17 14:32
    Model: deepseek-r1:8b
  ══════════════════════════════════════════════════════════════

    PORT 6379 — REDIS
    Risk: 🔴 Critical
    ────────────────────────────────────────────────────────────────
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

  ────────────────────────────────────────────
  Complete  ·  model: deepseek-r1:8b  ·  target: 192.168.1.10
  Logged to: C:\Users\Sam\.config\killport\attack.log
```

### `killport attack allports 192.168.1.10`
```
  AI Pentest  →  192.168.1.10  (all 65535 ports)
  ────────────────────────────────────────────

  Pass 1/2  Scanning 47 common ports on 192.168.1.10...

  ●  22        ssh           OpenSSH 8.9p1
  ●  80        http          Apache httpd 2.4.52

  Pass 2/2  scanning remaining 65535 ports on 192.168.1.10...

  [████████████████████░░░░░░░░░░░░░░░░░░░░]  51%
  ●  49152     unknown

  [████████████████████████████████████████] 100%
  Pass 2/2 complete.

  Agent starting  target: 192.168.1.10  ·  model: deepseek-r1:8b
  ...
```

### `killport attack log`
```
  Attack Log  C:\Users\Sam\.config\killport\attack.log

  ════════════════════════════════════════════════════════════
  Time:   2025-04-17 14:32:01  |  Target: 192.168.1.10
  Model:  deepseek-r1:8b       |  Ports:  47 common ports
  ════════════════════════════════════════════════════════════
  ... (full report) ...
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

> **Point it at any machine on your network. Watch an AI hunt for vulnerabilities in real time.**

`killport attack` is a fully agentic AI pentest tool powered by [Ollama](https://ollama.com) — your local AI, running entirely on your hardware, no cloud, no API keys. It doesn't just run a scan and hand you a wall of output. It **thinks**, **acts**, and **investigates** — probing services, testing credentials, hunting for exposed paths, and attempting to crack hashes — then delivers a plain-English security report with specific fix steps anyone can follow.

**Everything runs locally. Your scan data never leaves your machine.**

### Zero setup friction — missing tools install themselves

When you run `killport attack`, it checks whether `nmap`, `sshpass`, and `hashcat` are installed. If any are missing, it asks to install them for you **right there** — no new terminal, no manual steps:

```
  nmap not installed — needed for port/service scanning.
  Install nmap now via Chocolatey? [Y/n] → y
  ... choco install nmap -y ...
  Continuing.
```

Auto-detects your package manager: Chocolatey, winget, or Scoop. If none are found, it shows the direct download link.

### Setup

1. [Install Ollama](https://ollama.com/download) and pull a model:
   ```sh
   ollama pull llama3.2
   # or try a reasoning model:
   ollama pull deepseek-r1:8b
   ```
2. Configure killport to point at your Ollama instance:
   ```sh
   killport attack config
   ```
   - **This machine:** `localhost:11434` or `127.0.0.1:11434`
   - **Another LAN machine:** `192.168.x.x:11434`
   - **Remote server:** `45.76.x.x:11434` *(port 11434 must be open)*

   The config screen connects live to Ollama and shows you the models you have loaded — pick one by number.

3. Run your first attack:
   ```sh
   killport attack 192.168.1.10
   ```
   That's it. The AI takes over from there.

### Commands

```sh
killport attack 192.168.1.10            # scan 47 common ports (fast)
killport attack allports 192.168.1.10   # scan all 65535 ports with progress bar
killport attack 192.168.1.10:6379       # deep dive a single port
killport attack config                  # configure Ollama host + pick model
killport attack log                     # view full history of past attacks
```

### How it works

The agent runs a **ReAct loop** — Ollama reasons about what to investigate next, calls a tool, receives the result, and iterates (up to 20 rounds). The AI drives the entire investigation. You just watch it work.

| Tool | What the AI can do |
|---|---|
| `SCAN_PORT` | Deep nmap scan with version detection on any port |
| `BANNER_GRAB` | Raw TCP banner grab — extracts version strings and hashes |
| `HTTP_PROBE` | Fetch HTTP/HTTPS responses — extracts embedded hashes |
| `HTTP_PATHS` | Probe 20+ sensitive paths: `/admin`, `/.env`, `/actuator/env`, `/.git/HEAD`, etc. |
| `WORDLIST` | Credential spray across SSH, FTP, Redis, MySQL, PostgreSQL, HTTP basic auth |
| `NMAP_SCRIPT` | Run any nmap NSE script against any port |
| `CRACK_HASH` | Crack MD5 / SHA1 / SHA256 / bcrypt / MD5crypt / SHA512crypt via hashcat or john + rockyou |

The security report is **built programmatically** — risk levels, fix steps, and priority order are all deterministic code, not AI guesswork. Ollama contributes plain-English descriptions of each finding. The result is consistent, structured, and logged to `%APPDATA%\killport\attack.log` after every run.

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
