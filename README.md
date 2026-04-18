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

Also available for [macOS](https://github.com/skosari/killport-mac) and [Linux](https://github.com/skosari/killport-linux)

AI-powered pentesting, vulnerability scanning, and automated hardening via [Ollama](https://ollama.com) — runs entirely on your hardware

[![Version](https://img.shields.io/badge/version-1.10.3-00b4d8?style=flat-square)](#)
[![Platform](https://img.shields.io/badge/platform-Windows-00b4d8?style=flat-square&logo=windows&logoColor=white)](#)
[![Shell](https://img.shields.io/badge/shell-PowerShell%20%2F%20CMD-00b4d8?style=flat-square&logo=powershell&logoColor=white)](#)
[![License](https://img.shields.io/badge/license-Source%20Available-00b4d8?style=flat-square)](LICENSE)

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
| `killport openports <ip>` | Probe an IP to verify which ports are reachable |
| `killport closedports` | Show all listening ports with no external access |
| `killport status <port>` | Show if a port is open or closed |
| `killport ip` | Show IP addresses, DNS, and network info |
| `killport scan <ip>` | Scan ports on a remote host (no AI) |
| `killport scan <ip> all` | Scan all 65535 ports on a remote host |
| `killport watch <port>` | Monitor live connections to a local port |
| `killport cert <host:port>` | Inspect TLS certificate (expiry, SANs, cipher) |
| `killport sniff <port>` | Capture and display traffic on a port (pktmon) |
| `killport sniff <ip:port>` | Capture traffic to/from a specific host:port |
| `killport vuln <ip:port>` | Detect service version + query CVE database |
| `killport fix <ip:port>` | Detect vulns and generate/apply a hardening fix |
| `killport audit` | Review firewall rules with plain-English findings |
| `killport dns <domain>` | DNS recon: A/MX/TXT/NS/AXFR zone transfer test |
| `killport forward <port> <host:port>` | Forward a local port to a remote host:port |
| `killport stress <ip:port>` | Authorized connection flood / stress test |
| `killport attack <ip>` | AI pentest: scan 47 common ports + analysis |
| `killport attack allports <ip>` | AI pentest: scan all 65535 ports + analysis |
| `killport attack <ip>:<port>` | AI pentest: single port deep dive |
| `killport config` | Configure Ollama host and model |
| `killport attack log` | View attack history |
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

### `killport openports 192.168.1.10`
```
  External Port Check  -> 192.168.1.10
  ────────────────────────────────────────────

  ●  22        open   ssh
  ●  80        open   http
  ●  443       open   https

  ────────────────────────────────────────────
  3 open port(s) found  ·  scanned 30 common ports via nmap
```

### `killport scan 192.168.1.10`
```
  killport scan  192.168.1.10
  ────────────────────────────────────────────

  Scanning common ports...

  PORT     SERVICE             VERSION
  ────────────────────────────────────────────────────
  22       ssh                 OpenSSH 9.2p1
  80       http                nginx 1.24.0
  3306     mysql               MySQL 8.0.33
  6379     redis               Redis key-value store
```

### `killport watch 3000`
```
  killport watch  port 3000  (Ctrl+C to stop)
  ────────────────────────────────────────────

  TIME        REMOTE                      STATE
  ─────────────────────────────────────────────
  14:32:01    192.168.1.55:51204          ESTABLISHED
  14:32:09    192.168.1.55:51204          CLOSE_WAIT
```

### `killport cert github.com`
```
  killport cert  github.com:443
  ────────────────────────────────────────────

  Subject :  CN=github.com
  Issuer  :  C=US, O=DigiCert Inc, CN=DigiCert TLS Hybrid ECC SHA384 2020 CA1
  Expires :  2026-03-26  (341 days)
  SANs    :
    github.com
    www.github.com

  Protocol: Tls13
  Cipher  : Aes128
```

### `killport sniff 443`
```
  killport sniff  port 443  (Ctrl+C to stop)
  ────────────────────────────────────────────

  Filter: port 443. Requires Administrator.
  Press Ctrl+C to stop.

  14:32:01.123  [pktmon packet output...]
```

### `killport sniff 192.168.1.10:22`
```
  killport sniff  192.168.1.10:22  (Ctrl+C to stop)
  ────────────────────────────────────────────

  Filter: host 192.168.1.10 and port 22. Requires Administrator.
```

### `killport vuln 192.168.1.10:22`
```
  killport vuln  192.168.1.10:22
  ────────────────────────────────────────────

  Detecting service on port 22...

  Service:  ssh
  Version:  OpenSSH 9.2p1

  Querying NVD database...

  85 CVE(s) found — showing top 10:

  CVE-2023-38408  [CRITICAL  9.8]
  The PKCS#11 feature in ssh-agent in OpenSSH before 9.3p2 has an insufficiently...
```

### `killport fix 192.168.1.10:22`
```
  killport fix  192.168.1.10:22
  ────────────────────────────────────────────

  Detecting service on port 22...

  Service:  ssh
  Version:  OpenSSH 9.2p1

  ✓  Target is this machine — can apply fixes directly.

  ────────────────────────────────────────────
  AI Remediation Advice

  UPGRADE: winget upgrade --id Microsoft.OpenSSH.Beta -e

  CONFIG:
    PermitRootLogin no
    MaxAuthTries 3
    X11Forwarding no
    PermitEmptyPasswords no

  NETWORK: netsh advfirewall firewall add rule name="SSH restrict" protocol=TCP
           dir=in localport=22 remoteip=192.168.1.0/24 action=allow

  ────────────────────────────────────────────
  Apply these fixes now? (requires Admin)  [yes/N]: yes

    [fix] SSH hardened and restarted
    [fix] OpenSSH upgrade attempted via winget
    [fix] Fix script completed

  ✓  Fixes applied.  Verify with: killport vuln 192.168.1.10:22
```

### `killport audit`
```
  killport audit  firewall rule review
  ────────────────────────────────────────────

  Windows Firewall rules (inbound, enabled):

  ✓  12 explicit block rule(s) present.
  ⚠  Broad allow-all rules detected — review these carefully.

  Run 'killport openports' to cross-reference currently exposed ports.
```

### `killport dns github.com`
```
  killport dns  github.com
  ────────────────────────────────────────────

  A         140.82.121.4
  AAAA      (none)
  MX        10 aspmx.l.google.com
  NS        ns-1707.awsdns-21.co.uk
  TXT       "v=spf1 ip4:192.30.252.0/22 ~all"

  REVERSE
    140.82.121.4  ->  lb-140-82-121-4-iad.github.com

  AXFR
    ✓  Zone transfers blocked.
```

### `killport forward 8080 192.168.1.10:80`
```
  killport forward  localhost:8080  ->  192.168.1.10:80
  ────────────────────────────────────────────

  Using .NET socket forwarder (single connection at a time)
  Install ncat for full multi-connection support: https://nmap.org
  Press Ctrl+C to stop.

  Listening on port 8080...
```

### `killport stress 192.168.1.10:80`
```
  killport stress  authorized connection flood testing
  ────────────────────────────────────────────

  Target:   192.168.1.10:80  (service: http)

  Duration in seconds [default 30]: 30

  ⚠  This will flood 192.168.1.10:80 for 30s at up to 20 concurrent connections.
  Only test systems you own or have written authorization to test.

  Type yes to confirm: yes

  /-  [================--------]  12,847 req  428/s  0 err  18s left

  ====================================================
  STRESS TEST COMPLETE
  ====================================================
  Service:   http  (192.168.1.10:80)
  Duration:  30s  Threads: 20
  Requests:  18,432  (614/s avg  891/s peak)
  Errors:    0  (0%)
  After:     ONLINE - still responding
  ====================================================
```

### `killport attack 192.168.1.10`
```
  AI Pentest  →  192.168.1.10  (47 common ports)
  ────────────────────────────────────────────

  Connecting to Ollama at localhost:11434...
  Model: deepseek-r1:8b

  Scanning 47 common ports on 192.168.1.10...

  ●  80        http          Apache httpd 2.4.52
  ●  6379      redis         Redis key-value store

  Agent starting  target: 192.168.1.10  ·  model: deepseek-r1:8b

  💭 Redis with no auth is a critical finding — testing now
  ▶  WORDLIST redis 6379
     CRITICAL: Redis has NO password — fully open to anyone
  ▶  REPORT

  ══════════════════════════════════════════════════════════════
    SECURITY REPORT  ·  192.168.1.10  ·  2025-04-18 14:32
  ══════════════════════════════════════════════════════════════

    PORT 6379 — REDIS
    Risk: 🔴 Critical
    ⚠  NO PASSWORD REQUIRED

    How to fix it:
      1. Add requirepass to redis.conf
      2. Run: killport fix 192.168.1.10:6379

  Logged to: C:\ProgramData\killport\attack_log.txt
```

---

## Security Toolkit

killport includes a full suite of network security tools.

### Vulnerability Detection → `killport vuln`

```sh
killport vuln 192.168.1.10:22    # SSH
killport vuln 192.168.1.10:6379  # Redis
killport vuln 192.168.1.10:3306  # MySQL
```

### One-Command Hardening → `killport fix`

Automated fix after `vuln`. Local = apply directly; remote = generate a PowerShell script:

```sh
killport fix 127.0.0.1:6379       # harden local Redis
killport fix 192.168.1.10:22      # generate SSH fix script for remote machine
```

Supports: SSH (OpenSSH for Windows), Redis, MySQL, IIS, FTP.

### Port Scanner → `killport scan`

```sh
killport scan 192.168.1.10        # common ports
killport scan 192.168.1.10 all    # all 65535 ports
```

### TLS Certificate Inspector → `killport cert`

Uses the .NET `SslStream` — no openssl required:

```sh
killport cert github.com           # port 443 by default
killport cert 192.168.1.10:8443    # custom port
```

### Live Traffic Capture → `killport sniff`

Uses `pktmon` (Windows 10 1809+, requires Administrator):

```sh
killport sniff 443                      # all traffic on port 443
killport sniff 192.168.1.10:22          # traffic to/from specific host:port
```

### Live Connection Monitor → `killport watch`

```sh
killport watch 3000    # watch new connections in real time
```

### DNS Recon → `killport dns`

Uses `Resolve-DnsName` (built into Windows, no extra tools needed):

```sh
killport dns example.com
```

### Firewall Audit → `killport audit`

```sh
killport audit    # reviews Windows Firewall inbound rules
```

### Port Forwarder → `killport forward`

Uses `ncat` if installed, otherwise .NET sockets:

```sh
killport forward 8080 192.168.1.10:80
```

### Stress Test → `killport stress`

```sh
killport stress 192.168.1.10:80    # authorized connection flood test
```

---

## AI Penetration Testing

> **Point it at any machine on your network. Watch an AI hunt for vulnerabilities in real time.**

`killport attack` is a fully agentic AI pentest tool powered by [Ollama](https://ollama.com) — runs entirely on your hardware, no cloud, no API keys.

### Setup

1. [Install Ollama](https://ollama.com/download) and pull a model:
   ```sh
   ollama pull llama3.2
   ollama pull deepseek-r1:8b   # reasoning model
   ```
2. Configure killport:
   ```sh
   killport config
   ```
3. Run:
   ```sh
   killport attack 192.168.1.10
   ```

### Commands

```sh
killport attack 192.168.1.10            # scan 47 common ports
killport attack allports 192.168.1.10   # scan all 65535 ports
killport attack 192.168.1.10:6379       # single port deep dive
killport config                  # configure Ollama host + model
killport attack log                     # view past attack reports
```

### Agent tools

| Tool | What the AI can do |
|---|---|
| `SCAN_PORT` | Deep nmap scan with version detection |
| `BANNER_GRAB` | Raw TCP banner grab |
| `HTTP_PROBE` | Fetch HTTP/HTTPS paths, extract hashes |
| `HTTP_PATHS` | Probe 20+ sensitive paths: `/admin`, `/.env`, `/.git/HEAD`, etc. |
| `WORDLIST` | Credential spray: SSH, FTP, Redis, MySQL, PostgreSQL, HTTP |
| `NMAP_SCRIPT` | Run any nmap NSE script |
| `CRACK_HASH` | Crack MD5/SHA1/SHA256/bcrypt via hashcat or john |

---

## Notes

- `killport open` / `killport close` manage Windows Firewall inbound rules — run as Administrator
- `killport sniff` uses `pktmon` (Windows 10 1809+) — run as Administrator
- `killport fix` generates PowerShell scripts; remote fix scripts can be deployed via `scp` + `ssh`
- `killport cert` uses built-in .NET — no openssl needed
- `killport dns` uses `Resolve-DnsName` — no dig needed

---

## Uninstall

**Option 1 — built-in command** *(run as Administrator)*

```sh
killport uninstall
```

Removes the binary, implementation files, and all firewall rules created by `killport open`.

**Option 2 — PowerShell** *(elevated — Run as Administrator)*

```powershell
irm https://raw.githubusercontent.com/skosari/killport-win/main/uninstall.ps1 | iex
```

**Option 3 — Command Prompt (CMD)** *(elevated — Run as Administrator)*

```cmd
curl -fsSL https://raw.githubusercontent.com/skosari/killport-win/main/uninstall.ps1 -o "%TEMP%\kp-uninstall.ps1" && powershell -ExecutionPolicy Bypass -File "%TEMP%\kp-uninstall.ps1"
```

---

<div align="center">

Made by [skosari](https://github.com/skosari) · [killport-mac](https://github.com/skosari/killport-mac) · [killport-win](https://github.com/skosari/killport-win) · [killport-linux](https://github.com/skosari/killport-linux)

</div>
