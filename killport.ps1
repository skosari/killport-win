param(
    [Parameter(Mandatory=$false, Position=0)] [string]$Command,
    [Parameter(Mandatory=$false, Position=1)] [string]$Port
)

$VERSION = "1.6.7"
$REPO    = "skosari/killport-win"
$RAW     = "https://raw.githubusercontent.com/$REPO/main"

# ── helpers ─────────────────────────────────────────────────────────────────

function wh($msg, $fg, [switch]$nl = $true) {
    if ($fg) { Write-Host $msg -ForegroundColor $fg -NoNewline:(!$nl) }
    else     { Write-Host $msg -NoNewline:(!$nl) }
}

function Get-RemoteVersion {
    try { return (Invoke-WebRequest -Uri "$RAW/VERSION" -UseBasicParsing -TimeoutSec 2).Content.Trim() }
    catch { return $null }
}

# ── banner ───────────────────────────────────────────────────────────────────

function Show-Banner {
    Write-Host ""
    wh "██╗  ██╗██╗██╗     ██╗     ██████╗  ██████╗ ██████╗ ████████╗" Cyan
    wh "██║ ██╔╝██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝" Cyan
    wh "█████╔╝ ██║██║     ██║     ██████╔╝██║   ██║██████╔╝   ██║   " Cyan
    wh "██╔═██╗ ██║██║     ██║     ██╔═══╝ ██║   ██║██╔══██╗   ██║   " Cyan
    wh "██║  ██╗██║███████╗███████╗██║     ╚██████╔╝██║  ██╗   ██║   " Cyan
    wh "╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   " Cyan
    Write-Host ""
    wh "  https://github.com/skosari/killport-win" DarkGray
    Write-Host ""
}

function Show-Version {
    $remote = Get-RemoteVersion
    if ($remote -and $remote -ne $VERSION) {
        wh "  v$VERSION  " DarkGray -nl:$false; wh "→  v$remote available" Yellow -nl:$false; wh "  (run: killport update)" DarkGray
    } else {
        wh "  v$VERSION" DarkGray
    }
    Write-Host ""
}

function Write-Rule {
    wh "  ────────────────────────────────────────────" Cyan
}

# ── list ─────────────────────────────────────────────────────────────────────

function List-Ports {
    Write-Host ""
    wh "  Listening Ports" Cyan
    Write-Rule
    Write-Host ""
    $seen = @{}
    netstat -ano | Select-String "LISTENING" | ForEach-Object {
        $p = ($_ -split '\s+') | Where-Object { $_ -ne '' }
        $addr = $p[1]; $pid = $p[-1]
        if ($seen["$addr-$pid"]) { return }
        $seen["$addr-$pid"] = $true
        try   { $name = (Get-Process -Id $pid -ErrorAction Stop).Name }
        catch { $name = "(unknown)" }
        wh "  " -nl:$false; wh "●" Green -nl:$false
        Write-Host ("  {0,-28} " -f $addr) -NoNewline
        wh $name DarkGray
    }
    Write-Host ""
}

# ── ip ───────────────────────────────────────────────────────────────────────

function Show-IP {
    Write-Host ""
    wh "  Network Addresses" Cyan
    Write-Rule
    Write-Host ""

    $allAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    $withIPv4 = @()
    foreach ($a in $allAdapters) {
        $ip = Get-NetIPAddress -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
              Select-Object -First 1
        if ($ip) { $withIPv4 += [PSCustomObject]@{ Adapter=$a; IPv4=$ip.IPAddress } }
    }

    # secondary adapters (dim)
    for ($i = 1; $i -lt $withIPv4.Count; $i++) {
        $d = $withIPv4[$i]
        wh "  $($d.Adapter.Name)  ($($d.Adapter.InterfaceDescription))" DarkGray
        wh "  ──> $($d.IPv4)" DarkGray
        Write-Host ""
    }

    # primary adapter in box
    if ($withIPv4.Count -gt 0) {
        $pr = $withIPv4[0]
        wh "  ┌────────────────────────────────────────" Cyan
        wh "  │  " Cyan -nl:$false; Write-Host "$($pr.Adapter.Name)  " -NoNewline; wh "($($pr.Adapter.InterfaceDescription))" DarkGray
        wh "  │  " Cyan -nl:$false; wh "IPv4:  " White -nl:$false; wh $pr.IPv4 Green
        wh "  │  " Cyan -nl:$false; wh "MAC:   $($pr.Adapter.MacAddress)" DarkGray
        wh "  └────────────────────────────────────────" Cyan
        Write-Host ""
    }

    wh "  Default Gateway" White
    wh "  ────────────────────────────────────" Cyan
    Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object {
        $iName = (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).Name
        wh "  $($_.NextHop)  " -nl:$false; wh "($iName)" DarkGray
    }
    Write-Host ""

    wh "  DNS Servers" White
    wh "  ────────────────────────────────────" Cyan
    $shown = @{}
    Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | ForEach-Object {
        $iAlias = $_.InterfaceAlias
        $_.ServerAddresses | ForEach-Object {
            if (-not $shown[$_]) { $shown[$_] = $true; wh "  $_  " -nl:$false; wh "($iAlias)" DarkGray }
        }
    }
    Write-Host ""

    wh "  Firewall-managed ports (killport)" White
    wh "  ────────────────────────────────────" Cyan
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -notmatch "udp$" }
    if ($rules) {
        $rules | ForEach-Object { $f = $_ | Get-NetFirewallPortFilter; wh "  $($f.LocalPort)" -nl:$false; wh "  ($($_.Direction))" DarkGray }
    } else { wh "  None" DarkGray }
    Write-Host ""
}

# ── open / close ──────────────────────────────────────────────────────────────

function Open-Port($p) {
    Write-Host "Opening port " -NoNewline; wh $p White -nl:$false; Write-Host " to external connections..."
    try {
        New-NetFirewallRule -DisplayName "killport-$p"     -Direction Inbound -Protocol TCP -LocalPort $p -Action Allow -ErrorAction Stop | Out-Null
        New-NetFirewallRule -DisplayName "killport-$p-udp" -Direction Inbound -Protocol UDP -LocalPort $p -Action Allow -ErrorAction Stop | Out-Null
        wh "Port $p is now open (TCP + UDP)." Green
    } catch { wh "Failed to open port. Try running as Administrator." Yellow }
}

function Close-Port($p) {
    Write-Host "Closing port " -NoNewline; wh $p White -nl:$false; Write-Host " from external connections..."
    Remove-NetFirewallRule -DisplayName "killport-$p"     -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "killport-$p-udp" -ErrorAction SilentlyContinue
    wh "Port $p is now closed." DarkGray
}

# ── status ───────────────────────────────────────────────────────────────────

function Status-Port($p) {
    Write-Host ""
    Write-Host "  Port " -NoNewline; wh $p White -nl:$false; Write-Host " status:"
    Write-Host ""
    if (Get-NetFirewallRule -DisplayName "killport-$p" -ErrorAction SilentlyContinue) {
        wh "  Firewall:  " -nl:$false; wh "OPEN" Green -nl:$false; Write-Host "  (killport rule allows external access)"
    } else {
        wh "  Firewall:  " -nl:$false; wh "CLOSED" DarkGray -nl:$false; Write-Host "  (no killport rule — external access blocked)"
    }
    $conn = netstat -ano | Select-String ":$p\s" | Select-String /i "LISTENING"
    if ($conn) {
        $pid = (($conn | Select-Object -First 1) -split '\s+')[-1]
        try   { $name = (Get-Process -Id $pid -ErrorAction Stop).Name }
        catch { $name = "?" }
        wh "  Listening: " -nl:$false; wh "YES" Green -nl:$false; Write-Host "  (PID: $pid — $name)"
    } else {
        wh "  Listening: " -nl:$false; wh "NO" DarkGray -nl:$false; Write-Host "  (nothing is running on this port)"
    }
    Write-Host ""
}

# ── openports ────────────────────────────────────────────────────────────────

function Open-Ports {
    Write-Host ""
    wh "  Firewall-Open Ports" Cyan -nl:$false; wh "  (external access via killport)" DarkGray
    Write-Rule
    Write-Host ""
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -notmatch "udp$" }
    if (-not $rules) {
        wh "  No ports are currently open to external access." DarkGray
        wh "  Run: killport open <port>" DarkGray
    } else {
        $oc = 0; $lc = 0
        foreach ($rule in $rules) {
            $port = ($rule | Get-NetFirewallPortFilter).LocalPort
            $oc++
            $conn = netstat -ano | Select-String ":$port\s" | Select-String /i "LISTENING"
            if ($conn) {
                $lc++
                $pid = (($conn | Select-Object -First 1) -split '\s+')[-1]
                try { $name = (Get-Process -Id $pid -ErrorAction Stop).Name } catch { $name = "unknown" }
                wh "  " -nl:$false; wh "●" Green -nl:$false
                Write-Host ("  {0,-8}  " -f $port) -NoNewline; wh "listening" Green -nl:$false; wh "   $name" DarkGray
            } else {
                wh "  " -nl:$false; wh "○" Yellow -nl:$false
                Write-Host ("  {0,-8}  " -f $port) -NoNewline; wh "not listening" DarkGray
            }
        }
        Write-Host ""
        Write-Rule
        wh "  $oc port(s) open  ·  $lc listening" DarkGray
    }
    Write-Host ""
}

# ── closedports ──────────────────────────────────────────────────────────────

function Closed-Ports {
    Write-Host ""
    wh "  Locally-Listening Ports" Cyan -nl:$false; wh "  (no external access)" DarkGray
    Write-Rule
    Write-Host ""
    $openPorts = @()
    Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -notmatch "udp$" } |
        ForEach-Object { $openPorts += ($_ | Get-NetFirewallPortFilter).LocalPort }
    $seen = @{}; $count = 0
    netstat -ano | Select-String "LISTENING" | ForEach-Object {
        $parts = ($_ -split '\s+') | Where-Object { $_ -ne '' }
        $addr = $parts[1]; $pid = $parts[-1]
        $port = ($addr -split ':')[-1]
        if ($seen[$port]) { return }
        $seen[$port] = $true
        if ($openPorts -notcontains $port) {
            $count++
            try { $name = (Get-Process -Id $pid -ErrorAction Stop).Name } catch { $name = "unknown" }
            wh "  " -nl:$false; wh "◆" Yellow -nl:$false
            Write-Host ("  {0,-8}  " -f $port) -NoNewline; wh "local only   $name" DarkGray
        }
    }
    Write-Host ""
    Write-Rule
    wh "  $count port(s) listening locally  ·  no external access" DarkGray
    Write-Host ""
}

# ── kill port ────────────────────────────────────────────────────────────────

function Kill-Port($p) {
    $conns = netstat -ano | Select-String ":$p\s" | Select-String /i "LISTENING"
    if (-not $conns) { wh "Nothing running on port $p" DarkGray; return }
    $pids = $conns | ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
    Write-Host ""
    Write-Host "  Port " -NoNewline; wh $p White -nl:$false; Write-Host " is in use:"
    Write-Host ""
    foreach ($pid in $pids) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            wh "  PID:  " White -nl:$false; Write-Host " $($proc.Id)"
            wh "  Name: " White -nl:$false; Write-Host " $($proc.Name)"
            Write-Host ""
        } catch {
            wh "  PID:  " White -nl:$false; wh " $pid  (info unavailable)" DarkGray; Write-Host ""
        }
    }
    $failed = $false
    foreach ($pid in $pids) {
        try { Stop-Process -Id $pid -Force -ErrorAction Stop }
        catch { wh "Could not kill PID $pid — try running as Administrator." Yellow; $failed = $true }
    }
    if (-not $failed) { wh "Killed." Green }
}

# ── update ───────────────────────────────────────────────────────────────────

function Update-Killport {
    Write-Host "Checking for updates..."
    $remote = Get-RemoteVersion
    if (-not $remote) { wh "Could not reach GitHub." Yellow; exit 1 }
    if ($remote -eq $VERSION) { wh "Already up to date (v$VERSION)" Green; exit 0 }
    Write-Host "Updating $VERSION " -NoNewline; wh "→" Yellow -nl:$false; Write-Host " $remote..."

    # Update bat wrapper in System32
    $batPath = (Get-Command killport -ErrorAction SilentlyContinue).Source
    if ($batPath -and $batPath.EndsWith('.bat')) {
        $content = (Invoke-WebRequest -Uri "$RAW/killport.bat" -UseBasicParsing).Content
        $content = $content -replace "`r`n","`n" -replace "`n","`r`n"
        [System.IO.File]::WriteAllText($batPath, $content, [System.Text.Encoding]::UTF8)
    }

    # Update this ps1 implementation
    $ps1Path = $PSCommandPath
    if (-not $ps1Path) { $ps1Path = "C:\ProgramData\killport\killport.ps1" }
    $content = (Invoke-WebRequest -Uri "$RAW/killport.ps1" -UseBasicParsing).Content
    [System.IO.File]::WriteAllText($ps1Path, $content, [System.Text.Encoding]::UTF8)

    wh "Updated to v$remote. Run killport to confirm." Green
}

# ── uninstall ─────────────────────────────────────────────────────────────────

function Uninstall-Killport {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        wh "Re-run as Administrator: right-click PowerShell → Run as administrator" Yellow; exit 1
    }
    Write-Host "Uninstalling killport..."
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue
    if ($rules) { $rules | Remove-NetFirewallRule; wh "  Removed $($rules.Count) firewall rule(s)" DarkGray }
    $bat = "$env:SystemRoot\System32\killport.bat"
    if (Test-Path $bat) { Remove-Item $bat -Force; wh "  Removed $bat" DarkGray }
    $impl = "$env:ProgramData\killport"
    if (Test-Path $impl) { Remove-Item $impl -Recurse -Force; wh "  Removed $impl" DarkGray }
    @(
        "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.ps1",
        "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.bat"
    ) | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Force; wh "  Removed $_" DarkGray }
    wh "killport uninstalled." Green
}

# ── main ─────────────────────────────────────────────────────────────────────

if (-not $Command) {
    Show-Banner
    Show-Version
    Write-Host "  killport                   show this help"
    Write-Host "  killport <port>            kill whatever is running on that port"
    Write-Host "  killport list              list all listening ports"
    Write-Host "  killport open <port>       open a port to external connections"
    Write-Host "  killport close <port>      close a port from external connections"
    Write-Host "  killport openports         show all ports open to external access"
    Write-Host "  killport closedports       show all listening ports with no external access"
    Write-Host "  killport status <port>     show if a port is open or closed"
    Write-Host "  killport ip                show IP addresses and network info"
    Write-Host "  killport update            update to the latest version"
    Write-Host "  killport uninstall         remove killport and all firewall rules"
    Write-Host ""
    exit 0
}

switch ($Command.ToLower()) {
    "update"      { Update-Killport }
    "uninstall"   { Uninstall-Killport }
    "list"        { List-Ports }
    "openports"   { Open-Ports }
    "closedports" { Closed-Ports }
    "ip"          { Show-IP }
    "status"      { if (-not $Port) { Write-Host "Usage: killport status <port>" } else { Status-Port $Port } }
    "open"        { if (-not $Port) { Write-Host "Usage: killport open <port>" } else { Open-Port $Port } }
    "close"       { if (-not $Port) { Write-Host "Usage: killport close <port>" } else { Close-Port $Port } }
    default {
        $p = $Command
        if ($p -notmatch '^\d+$' -or [int]$p -lt 1 -or [int]$p -gt 65535) {
            wh "Error: '$p' is not a valid port number (1-65535)" Yellow; exit 1
        }
        Kill-Port $p
    }
}
