param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Command,
    [Parameter(Mandatory=$false, Position=1)]
    [string]$Port
)

$VERSION = "1.6.6"
$REPO = "skosari/killport-win"
$RAW = "https://raw.githubusercontent.com/$REPO/main"

function Show-Banner {
    $lines = @(
        "██╗  ██╗██╗██╗     ██╗     ██████╗  ██████╗ ██████╗ ████████╗",
        "██║ ██╔╝██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝",
        "█████╔╝ ██║██║     ██║     ██████╔╝██║   ██║██████╔╝   ██║   ",
        "██╔═██╗ ██║██║     ██║     ██╔═══╝ ██║   ██║██╔══██╗   ██║   ",
        "██║  ██╗██║███████╗███████╗██║     ╚██████╔╝██║  ██╗   ██║   ",
        "╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   "
    )
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Cyan
    }
    Write-Host ""
}

function Check-Update {
    try {
        $remote = (Invoke-WebRequest -Uri "$RAW/VERSION" -UseBasicParsing -TimeoutSec 2).Content.Trim()
        if ($remote -and $remote -ne $VERSION) {
            Write-Host "  Update available: $VERSION -> $remote  (run: killport update)" -ForegroundColor Yellow
            Write-Host ""
        }
    } catch {}
}

function List-Ports {
    Write-Host "Listening ports:"
    Write-Host ""
    $connections = netstat -ano | Select-String "LISTENING"
    $seen = @{}
    foreach ($line in $connections) {
        $parts = ($line -split '\s+') | Where-Object { $_ -ne '' }
        $localAddr = $parts[1]; $pid = $parts[-1]
        if ($seen[$pid + $localAddr]) { continue }
        $seen[$pid + $localAddr] = $true
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, $proc.Name, $pid)
        } catch {
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, "(unknown)", $pid)
        }
    }
}

function Open-Port($p) {
    Write-Host "Opening port $p to external connections..."
    $ruleName = "killport-$p"
    try {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $p -Action Allow -ErrorAction Stop | Out-Null
        New-NetFirewallRule -DisplayName "${ruleName}-udp" -Direction Inbound -Protocol UDP -LocalPort $p -Action Allow -ErrorAction Stop | Out-Null
        Write-Host "Port $p is now open (TCP + UDP)."
    } catch {
        Write-Error "Failed to open port. Try running as Administrator."
    }
}

function Close-Port($p) {
    Write-Host "Closing port $p from external connections..."
    $ruleName = "killport-$p"
    try {
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "${ruleName}-udp" -ErrorAction SilentlyContinue
        Write-Host "Port $p is now closed."
    } catch {
        Write-Error "Failed to close port. Try running as Administrator."
    }
}

function Status-Port($p) {
    Write-Host "Port $p status:"
    Write-Host ""

    # Firewall rule
    $rule = Get-NetFirewallRule -DisplayName "killport-$p" -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "  Firewall:  OPEN  (killport rule allows external access)"
    } else {
        Write-Host "  Firewall:  CLOSED  (no killport rule — external access blocked)"
    }

    # Actively listening
    $conn = netstat -ano | Select-String ":$p\s" | Select-String /i "LISTENING"
    if ($conn) {
        $pid = (($conn | Select-Object -First 1) -split '\s+')[-1]
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            Write-Host "  Listening: YES  (PID: $pid — $($proc.Name))"
        } catch {
            Write-Host "  Listening: YES  (PID: $pid)"
        }
    } else {
        Write-Host "  Listening: NO  (nothing is running on this port)"
    }
}

function Open-Ports {
    Write-Host "Open ports (allowed external access via killport):"
    Write-Host ""
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -notmatch "udp$" }
    if (-not $rules) { Write-Host "  None — no ports have been opened with killport."; return }
    foreach ($rule in $rules) {
        $filter = $rule | Get-NetFirewallPortFilter
        $port = $filter.LocalPort
        $conn = netstat -ano | Select-String ":$port\s" | Select-String /i "LISTENING"
        if ($conn) {
            $pid = (($conn | Select-Object -First 1) -split '\s+')[-1]
            try { $name = (Get-Process -Id $pid -ErrorAction Stop).Name } catch { $name = "unknown" }
            Write-Host ("  {0,-8}  listening  ({1})" -f $port, $name)
        } else {
            Write-Host ("  {0,-8}  not listening" -f $port)
        }
    }
}

function Closed-Ports {
    Write-Host "Closed ports (listening locally, no external access):"
    Write-Host ""
    $openPorts = @()
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -notmatch "udp$" }
    foreach ($rule in $rules) {
        $openPorts += ($rule | Get-NetFirewallPortFilter).LocalPort
    }
    $connections = netstat -ano | Select-String "LISTENING"
    $seen = @{}
    foreach ($line in $connections) {
        $parts = ($line -split '\s+') | Where-Object { $_ -ne '' }
        $addr = $parts[1]; $pid = $parts[-1]
        $port = ($addr -split ':')[-1]
        if ($seen[$port]) { continue }
        $seen[$port] = $true
        if ($openPorts -notcontains $port) {
            try { $name = (Get-Process -Id $pid -ErrorAction Stop).Name } catch { $name = "unknown" }
            Write-Host ("  {0,-8}  closed  ({1})" -f $port, $name)
        }
    }
}

function Show-IP {
    Write-Host "Network Interfaces"
    Write-Host "────────────────────────────────────"
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $addrs = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "  Interface: $($adapter.Name)  ($($adapter.InterfaceDescription))"
        Write-Host "  MAC:       $($adapter.MacAddress)"
        foreach ($addr in $addrs) {
            Write-Host ("  {0,-8}  {1}/{2}" -f $addr.AddressFamily, $addr.IPAddress, $addr.PrefixLength)
        }
    }

    Write-Host ""
    Write-Host "Default Gateway"
    Write-Host "────────────────────────────────────"
    $gateways = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
    foreach ($gw in $gateways) {
        Write-Host "  $($gw.NextHop)  (via $((Get-NetAdapter -InterfaceIndex $gw.InterfaceIndex).Name))"
    }

    Write-Host ""
    Write-Host "DNS Servers"
    Write-Host "────────────────────────────────────"
    $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses }
    foreach ($dns in $dnsServers) {
        $dns.ServerAddresses | ForEach-Object { Write-Host "  $_  ($($dns.InterfaceAlias))" }
    }

    Write-Host ""
    Write-Host "Firewall-managed ports (killport)"
    Write-Host "────────────────────────────────────"
    $rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue
    if ($rules) {
        $rules | ForEach-Object {
            $filter = $_ | Get-NetFirewallPortFilter
            Write-Host ("  Port {0,-8} {1,-6} {2}" -f $filter.LocalPort, $filter.Protocol, $_.Direction)
        }
    } else {
        Write-Host "  None"
    }
}

# -------------------------------------------------------

if (-not $Command) {
    Show-Banner
    Write-Host "  v$VERSION"
    Write-Host ""
    Write-Host "  killport                   show this help and list listening ports"
    Write-Host "  killport <port>            kill whatever is running on that port"
    Write-Host "  killport list              list all listening ports"
    Write-Host "  killport open <port>       open a port to external connections"
    Write-Host "  killport close <port>      close a port from external connections"
    Write-Host "  killport openports         show all ports open to external access"
    Write-Host "  killport closedports       show all listening ports with no external access"
    Write-Host "  killport status <port>     show if a port is open or closed"
    Write-Host "  killport ip                show IP addresses, DNS, and network info"
    Write-Host "  killport update            update to the latest version"
    Write-Host ""
    Check-Update
    exit 0
}

switch ($Command.ToLower()) {

    "update" {
        Write-Host "Checking for updates..."
        try { $remote = (Invoke-WebRequest -Uri "$RAW/VERSION" -UseBasicParsing -TimeoutSec 5).Content.Trim() }
        catch { Write-Host "Could not reach GitHub."; exit 1 }
        if ($remote -eq $VERSION) { Write-Host "Already up to date (v$VERSION)"; exit 0 }
        Write-Host "Updating $VERSION -> $remote..."
        $installPath = (Get-Command killport -ErrorAction SilentlyContinue).Source
        if (-not $installPath) { $installPath = "$PSScriptRoot\killport.ps1" }
        Invoke-WebRequest -Uri "$RAW/killport.ps1" -OutFile $installPath -UseBasicParsing
        Write-Host "Updated to v$remote. Run killport to confirm."
    }

    "list" { List-Ports }

    "openports" { Open-Ports }

    "closedports" { Closed-Ports }

    "status" {
        if (-not $Port) { Write-Host "Usage: killport status <port>"; exit 1 }
        Status-Port $Port
    }

    "ip" { Show-IP }

    "open" {
        if (-not $Port) { Write-Host "Usage: killport open <port>"; exit 1 }
        Open-Port $Port
    }

    "close" {
        if (-not $Port) { Write-Host "Usage: killport close <port>"; exit 1 }
        Close-Port $Port
    }

    default {
        $p = $Command
        if ($p -notmatch '^\d+$' -or [int]$p -lt 1 -or [int]$p -gt 65535) {
            Write-Error "Error: '$p' is not a valid port number (1-65535)"; exit 1
        }
        $connections = netstat -ano | Select-String ":$p\s" | Select-String /i "LISTENING"
        if (-not $connections) { Write-Host "Nothing running on port $p"; exit 0 }
        $pids = $connections | ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
        Write-Host "Port $p is in use:"; Write-Host ""
        foreach ($pid in $pids) {
            try {
                $proc = Get-Process -Id $pid -ErrorAction Stop
                Write-Host "  PID:   $($proc.Id)"
                Write-Host "  Name:  $($proc.Name)"
                Write-Host "  Path:  $($proc.Path)"
                Write-Host ""
            } catch { Write-Host "  PID:   $pid (info unavailable)"; Write-Host "" }
        }
        foreach ($pid in $pids) {
            try { Stop-Process -Id $pid -Force -ErrorAction Stop }
            catch { Write-Warning "Could not kill PID $pid" }
        }
        Write-Host "Killed."
    }
}
