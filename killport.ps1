param(
    [Parameter(Mandatory=$false, Position=0)] [string]$Command,
    [Parameter(Mandatory=$false, Position=1)] [string]$Port,
    [Parameter(Mandatory=$false, Position=2)] [string]$Extra
)

$VERSION = "1.10.11"
$REPO    = "skosari/killport-win"
$RAW     = "https://raw.githubusercontent.com/$REPO/main"

$ProgressPreference = 'SilentlyContinue'

# ── helpers ─────────────────────────────────────────────────────────────────

function wh($msg, $fg, [switch]$nl = $true) {
    if ($fg) { Write-Host $msg -ForegroundColor $fg -NoNewline:(!$nl) }
    else     { Write-Host $msg -NoNewline:(!$nl) }
}

function Get-CmdPath([string]$Name) { $c = Get-Command $Name -ErrorAction SilentlyContinue; if ($c) { $c.Source } }

function Get-RemoteVersion {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Cache-Control", "no-cache")
        return $wc.DownloadString("$RAW/VERSION").Trim()
    } catch {
        try { return (Invoke-WebRequest -Uri "$RAW/VERSION" -UseBasicParsing -TimeoutSec 5).Content.Trim() }
        catch { return $null }
    }
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

function Compare-Version($a, $b) {
    $av = [version]($a -replace '[^0-9.]','')
    $bv = [version]($b -replace '[^0-9.]','')
    return $av.CompareTo($bv)
}

function Show-Version {
    $remote = Get-RemoteVersion
    if ($remote -and (Compare-Version $remote $VERSION) -gt 0) {
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
        $addr = $p[1]; $procPid = $p[-1]
        if ($seen["$addr-$procPid"]) { return }
        $seen["$addr-$procPid"] = $true
        try   { $name = (Get-Process -Id $procPid -ErrorAction Stop).Name }
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
        wh "  Firewall:  " -nl:$false; wh "CLOSED" DarkGray -nl:$false; Write-Host "  (no killport rule - external access blocked)"
    }
    $conn = netstat -ano | Where-Object { $_ -match ":$p\s" -and $_ -match "LISTENING" }
    if ($conn) {
        $procPid = (($conn | Select-Object -First 1) -split '\s+')[-1]
        try   { $name = (Get-Process -Id $procPid -ErrorAction Stop).Name }
        catch { $name = "?" }
        wh "  Listening: " -nl:$false; wh "YES" Green -nl:$false; Write-Host "  (PID: $procPid - $name)"
    } else {
        wh "  Listening: " -nl:$false; wh "NO" DarkGray -nl:$false; Write-Host "  (nothing is running on this port)"
    }
    Write-Host ""
}

# ── openports ────────────────────────────────────────────────────────────────

function Invoke-OpenCheck($target) {
    $PORTS = @(21,22,23,25,53,80,110,143,443,465,587,993,995,
               3000,3001,3306,4000,4200,5000,5173,5432,
               6379,8000,8080,8443,8888,9000,9090,9200,27017)
    Write-Host ""
    wh "  External Port Check" Cyan -nl:$false; wh "  -> $target" DarkGray
    Write-Rule; Write-Host ""
    $nmap = Get-CmdPath nmap
    if ($nmap) {
        wh "  Scanning with nmap..." DarkGray; Write-Host ""
        $portCsv = $PORTS -join ","
        $found = 0
        & $nmap -p $portCsv --open -T4 $target 2>$null | Where-Object { $_ -match '^\d+/tcp' } | ForEach-Object {
            $parts = $_ -split '\s+'; $port = $parts[0] -replace '/tcp'
            $svc = if ($parts.Count -ge 3) { $parts[2] } else { "" }
            wh "  ● " Green -nl:$false; wh ("{0,-8}  " -f $port) -nl:$false; wh "open   $svc" DarkGray
            $found++
        }
        if ($found -eq 0) { wh "  No open ports found on scanned list." DarkGray }
        Write-Host ""; Write-Rule
        wh "  $found open port(s) found  ·  scanned $($PORTS.Count) common ports via nmap" DarkGray
    } else {
        wh "  nmap not found — probing $($PORTS.Count) common ports with .NET (parallel)..." DarkGray; Write-Host ""
        $results = [System.Collections.Concurrent.ConcurrentBag[int]]::new()
        $jobs = $PORTS | ForEach-Object {
            $p = $_
            [System.Threading.Tasks.Task]::Run([System.Action]{
                try {
                    $tcp = [System.Net.Sockets.TcpClient]::new()
                    $ar = $tcp.BeginConnect($target, $p, $null, $null)
                    if ($ar.AsyncWaitHandle.WaitOne(1000)) { $tcp.EndConnect($ar); $results.Add($p) }
                    $tcp.Dispose()
                } catch {}
            }.GetNewClosure())
        }
        [System.Threading.Tasks.Task]::WaitAll($jobs)
        $sorted = $results | Sort-Object
        if ($sorted) {
            foreach ($p in $sorted) { wh "  ● " Green -nl:$false; wh ("{0,-8}  open" -f $p) DarkGray }
        } else { wh "  No open ports found on scanned list." DarkGray }
        Write-Host ""; Write-Rule
        wh "  $($sorted.Count) open port(s) found  ·  scanned $($PORTS.Count) common ports" DarkGray
        wh "  Install nmap for broader coverage: https://nmap.org" DarkGray
    }
    Write-Host ""
}

function Open-Ports($target) {
    if ($target) { Invoke-OpenCheck $target; return }
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
            $conn = netstat -ano | Where-Object { $_ -match ":$port\s" -and $_ -match "LISTENING" }
            if ($conn) {
                $lc++
                $procPid = (($conn | Select-Object -First 1) -split '\s+')[-1]
                try { $name = (Get-Process -Id $procPid -ErrorAction Stop).Name } catch { $name = "unknown" }
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
        $addr = $parts[1]; $procPid = $parts[-1]
        $port = ($addr -split ':')[-1]
        if ($seen[$port]) { return }
        $seen[$port] = $true
        if ($openPorts -notcontains $port) {
            $count++
            try { $name = (Get-Process -Id $procPid -ErrorAction Stop).Name } catch { $name = "unknown" }
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
    $conns = netstat -ano | Where-Object { $_ -match ":$p\s" -and $_ -match "LISTENING" }
    if (-not $conns) { wh "Nothing running on port $p" DarkGray; return }
    $pids = $conns | ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
    Write-Host ""
    Write-Host "  Port " -NoNewline; wh $p White -nl:$false; Write-Host " is in use:"
    Write-Host ""
    foreach ($procPid in $pids) {
        try {
            $proc = Get-Process -Id $procPid -ErrorAction Stop
            wh "  PID:  " White -nl:$false; Write-Host " $($proc.Id)"
            wh "  Name: " White -nl:$false; Write-Host " $($proc.Name)"
            Write-Host ""
        } catch {
            wh "  PID:  " White -nl:$false; wh " $procPid  (info unavailable)" DarkGray; Write-Host ""
        }
    }
    $failed = $false
    foreach ($procPid in $pids) {
        try { Stop-Process -Id $procPid -Force -ErrorAction Stop }
        catch { wh "Could not kill PID $procPid - try running as Administrator." Yellow; $failed = $true }
    }
    if (-not $failed) { wh "Killed." Green }
}

# ── update ───────────────────────────────────────────────────────────────────

function Update-Killport {
    Write-Host "Checking for updates..."
    $remote = Get-RemoteVersion
    if (-not $remote) { wh "Could not reach GitHub." Yellow; exit 1 }
    if ((Compare-Version $remote $VERSION) -le 0) { wh "Already up to date (v$VERSION)" Green; exit 0 }
    Write-Host "Updating $VERSION " -NoNewline; wh "→" Yellow -nl:$false; Write-Host " $remote..."

    # Update bat wrapper in System32
    $batPath = (Get-Command killport -ErrorAction SilentlyContinue).Source
    if ($batPath -and $batPath.EndsWith('.bat')) {
        $content = (Invoke-WebRequest -Uri "$RAW/killport.bat" -UseBasicParsing).Content
        $content = $content -replace "`r`n","`n" -replace "`n","`r`n"
        [System.IO.File]::WriteAllText($batPath, $content, (New-Object System.Text.UTF8Encoding $False))
    }

    # Update this ps1 implementation
    $ps1Path = $PSCommandPath
    if (-not $ps1Path) { $ps1Path = "C:\ProgramData\killport\killport.ps1" }
    $content = (Invoke-WebRequest -Uri "$RAW/killport.ps1" -UseBasicParsing).Content
    [System.IO.File]::WriteAllText($ps1Path, $content, (New-Object System.Text.UTF8Encoding $True))

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

# ── attack ───────────────────────────────────────────────────────────────────

$ATTACK_CONF = "$env:ProgramData\killport\attack.conf"
$ATTACK_LOG  = "$env:ProgramData\killport\attack.log"

function Get-AttackConf {
    $conf = @{ ollama_host = "http://localhost:11434"; model = "llama3.2"; enabled = "false" }
    if (Test-Path $ATTACK_CONF) {
        Get-Content $ATTACK_CONF | ForEach-Object {
            if ($_ -match '^([^=]+)=(.+)$') { $conf[$Matches[1].Trim()] = $Matches[2].Trim() }
        }
    }
    return $conf
}

function Save-AttackConf($conf) {
    $conf.Keys | ForEach-Object { "$_=$($conf[$_])" } | Set-Content $ATTACK_CONF
}

function Show-AttackConfig {
    $conf = Get-AttackConf
    Write-Host ""
    wh "  Attack Config" Cyan
    Write-Rule
    Write-Host ""
    wh "  Config: " DarkGray -nl:$false; wh $ATTACK_CONF DarkGray
    Write-Host ""

    # ── Ollama host ──────────────────────────────────────────────────────────
    Write-Host ""
    wh "  Ollama Host" White
    wh "  Ollama is the AI engine that runs your models locally or on another machine." DarkGray
    wh "  Enter the host and port where Ollama is running:" DarkGray
    Write-Host ""
    wh "    * This machine:    " DarkGray -nl:$false; wh "localhost:11434" White -nl:$false; wh "  or  " DarkGray -nl:$false; wh "127.0.0.1:11434" White
    wh "    * Another LAN box: " DarkGray -nl:$false; wh "192.168.x.x:11434" White -nl:$false; wh "  (the IP of that machine)" DarkGray
    wh "    * Remote server:   " DarkGray -nl:$false; wh "45.76.x.x:11434" White -nl:$false; wh "   (must have port 11434 open)" DarkGray
    Write-Host ""
    wh "  Default port is always 11434. Press Enter to keep current value." DarkGray
    Write-Host ""
    wh "  Current: " -nl:$false; wh $conf.ollama_host White
    Write-Host "  -> " -NoNewline
    $h = Read-Host
    if ($h) { $conf.ollama_host = $h }

    # ── Connect and list models ──────────────────────────────────────────────
    $hostUrl = $conf.ollama_host
    if ($hostUrl -notmatch '^https?://') { $hostUrl = "http://$hostUrl" }
    $conf.ollama_host = $hostUrl

    Write-Host ""
    wh "  Connecting to Ollama at $hostUrl..." DarkGray
    $installedModels = @()
    $connected = $false
    try {
        $resp = Invoke-WebRequest -Uri "$hostUrl/api/tags" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $tags = ($resp.Content | ConvertFrom-Json).models
        $installedModels = if ($tags) { @($tags | ForEach-Object { $_.name }) } else { @() }
        $connected = $true
    } catch { }

    if (-not $connected) {
        Write-Host ""
        wh "  Cannot reach Ollama at $hostUrl" Red
        wh "  Start it with: ollama serve" DarkGray
        Write-Host ""
        Write-Host "  Save host anyway? [y/N] -> " -NoNewline
        $ans = Read-Host
        if ($ans -match '^[Yy]') {
            Save-AttackConf $conf
            wh "  Saved (no model selected - will auto-detect when reachable)." Yellow
        } else {
            wh "  Aborted. No changes saved." DarkGray
        }
        Write-Host ""
        return
    }

    if ($installedModels.Count -eq 0) {
        Write-Host ""
        wh "  Connected but no models are loaded." Yellow
        wh "  Pull one with: ollama pull llama3.2" DarkGray
        Write-Host ""
        Save-AttackConf $conf
        wh "  Host saved." Green
        Write-Host ""
        return
    }

    Write-Host ""
    wh "  Connected. " Green -nl:$false; wh "$($installedModels.Count) model(s) available:" DarkGray
    Write-Host ""
    $i = 1
    foreach ($mdl in $installedModels) {
        if ($mdl -eq $conf.model) {
            wh "  > " Green -nl:$false; wh ("{0,2}  {1}" -f $i, $mdl) White
        } else {
            wh ("     {0,2}  {1}" -f $i, $mdl) DarkGray
        }
        $i++
    }
    Write-Host ""
    wh "  0 = auto-detect (always use first loaded model)" DarkGray

    $currentDisplay = "auto"
    for ($j = 0; $j -lt $installedModels.Count; $j++) {
        if ($installedModels[$j] -eq $conf.model) { $currentDisplay = ($j + 1).ToString() }
    }

    Write-Host ""
    wh "  Select model " -nl:$false; wh "[current: $currentDisplay]" DarkGray
    Write-Host "  -> " -NoNewline
    $sel = Read-Host

    if ($sel -eq "") {
        # keep existing
    } elseif ($sel -eq "0") {
        $conf.model = ""
    } else {
        $idx = 0
        if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $installedModels.Count) {
            $conf.model = $installedModels[$idx - 1]
        } else {
            wh "  Invalid selection - keeping current." Yellow
        }
    }

    $conf.enabled = "true"
    Save-AttackConf $conf
    $savedModel = if ($conf.model) { $conf.model } else { "auto-detect" }
    Write-Host ""
    wh "  Saved.  " Green -nl:$false
    wh "Host: " -nl:$false; wh $conf.ollama_host White -nl:$false
    wh "  *  Model: " -nl:$false; wh $savedModel White
    Write-Host ""
}

function Show-AttackLog {
    if (-not (Test-Path $ATTACK_LOG)) { wh "  No attack log found." DarkGray; Write-Host ""; return }
    Get-Content $ATTACK_LOG | ForEach-Object { Write-Host $_ }
}

function Request-ToolInstall($tool, $desc) {
    Write-Host ""
    wh "  $tool not installed" Yellow
    Write-Host "  $desc"
    $mgr = $null
    if     (Get-Command choco  -ErrorAction SilentlyContinue) { $mgr = "choco"  }
    elseif (Get-Command winget -ErrorAction SilentlyContinue) { $mgr = "winget" }
    elseif (Get-Command scoop  -ErrorAction SilentlyContinue) { $mgr = "scoop"  }
    if ($mgr) {
        Write-Host "  Install with $mgr now? [Y/n] -> " -NoNewline
        $a = Read-Host
        if (-not $a -or $a -match '^[Yy]') {
            switch ($mgr) {
                "choco"  { & choco install $tool -y }
                "winget" { & winget install --id $tool }
                "scoop"  { & scoop install $tool }
            }
        } else { wh "  Skipping $tool (some features limited)." DarkGray }
    } else {
        wh "  No package manager found (choco/winget/scoop)." Yellow
        wh "  Install $tool manually from the web and re-run." DarkGray
    }
    Write-Host ""
}

function Start-AttackRun($target, [bool]$fullScan = $false) {
    $conf = Get-AttackConf
    if (-not $conf.ollama_host -or $conf.enabled -ne "true") {
        Write-Host ""
        wh "  killport attack is not configured." Yellow
        Write-Host "  Run: " -NoNewline; wh "killport config" White
        Write-Host ""
        return
    }

    if (-not (Get-Command nmap -ErrorAction SilentlyContinue)) {
        Request-ToolInstall "nmap" "needed for port/service scanning"
        if (-not (Get-Command nmap -ErrorAction SilentlyContinue)) { return }
    }
    if (-not (Get-Command hashcat -ErrorAction SilentlyContinue) -and
        -not (Get-Command john    -ErrorAction SilentlyContinue)) {
        Request-ToolInstall "hashcat" "needed for hash cracking (optional)"
    }

    $py = @("python","python3","py") |
          Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
          Select-Object -First 1
    if (-not $py) { wh "  Python not found. Install from https://python.org" Yellow; return }

    Write-Host ""
    wh "  killport attack" Cyan -nl:$false; Write-Host "  -  AI Penetration Test"
    Write-Rule
    wh "  Target: " White -nl:$false; wh $target Green
    Write-Host ""

    $barWidth  = 40
    $blockChar = [string][char]9608   # filled block
    $lightChar = [string][char]9617   # light shade
    $nmapLines = [System.Collections.Generic.List[string]]::new()

    if ($fullScan) {
        wh "  Scanning all 65535 ports" DarkGray -nl:$false; wh "  (this may take several minutes)" DarkGray
        Write-Host ""
        & nmap -p- --open -sV -T4 --stats-every 3s $target 2>&1 | ForEach-Object {
            $line = "$_"
            if ($line -match '(\d+(?:\.\d+)?)% done') {
                $pct    = [int][double]$Matches[1]
                $filled = [int]($pct * $barWidth / 100)
                $bar    = ($blockChar * $filled) + ($lightChar * ($barWidth - $filled))
                Write-Host "  [$bar] $($pct.ToString().PadLeft(3))%  `r" -NoNewline
            } else {
                $nmapLines.Add($line)
            }
        }
        Write-Host ("  " + (" " * ($barWidth + 10)) + "`r") -NoNewline
    } else {
        wh "  Scanning common ports..." DarkGray
        & nmap --open -sV -T4 $target 2>&1 | ForEach-Object { $nmapLines.Add("$_") }
    }

    $nmapOutput = $nmapLines -join "`n"
    if (-not $nmapOutput.Trim()) { wh "  nmap scan returned no output." Yellow; return }
    Write-Host ""; wh "  Scan complete." Green; Write-Host ""
    Write-Host $nmapOutput; Write-Host ""

    try {
        $null = (Invoke-WebRequest -Uri "$($conf.ollama_host)/api/tags" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop)
    } catch {
        wh "  Ollama not reachable at $($conf.ollama_host)" Yellow
        Write-Host "  Start Ollama and re-run, or update: " -NoNewline; wh "killport config" White
        return
    }

    wh "  Starting AI pentest agent" Cyan -nl:$false; wh "  (model: $($conf.model))" DarkGray
    Write-Host ""

    $pyScript = @'
import sys, json, subprocess, re, datetime, os, tempfile, urllib.request
from collections import defaultdict

target   = sys.argv[1]
host     = sys.argv[2]
model    = sys.argv[3]
log_path = sys.argv[4]
INITIAL  = sys.stdin.read()
DEPTH    = os.environ.get("KP_DEPTH","common")

MAX_IT = 20
B="\033[1m"; C="\033[0;36m"; D="\033[2m"; R="\033[0m"

findings = defaultdict(lambda:{
    "service":"","version":"","banner":"","no_auth":False,
    "creds_ok":[],"hashes":[],"cracked":[],"paths_found":[],"notes":[]
})

_USERS={"quick":["admin","root"],"common":["admin","root","user","test","administrator"],
        "deep":["admin","root","user","test","administrator","guest","service","backup","operator"]}
_PASSES={"quick":["","admin","password","123456"],
         "common":["","admin","password","123456","root","pass","test","guest","1234","letmein"],
         "deep":["","admin","password","123456","root","pass","test","guest","1234","letmein",
                 "welcome","master","qwerty","abc123","changeme","secret","P@ssw0rd","Admin1"]}
TOP_USERS  = _USERS.get(DEPTH, _USERS["common"])
TOP_PASSES = _PASSES.get(DEPTH, _PASSES["common"])

RISK_RULES = {
    "critical": lambda d: d["no_auth"] or bool(d["creds_ok"]),
    "high":     lambda d: any(s in (d["service"] or "").lower() for s in
                              ["telnet","ftp","redis","mongodb","vnc"]) or bool(d["cracked"]),
    "medium":   lambda d: any(s in (d["service"] or "").lower() for s in
                              ["ssh","http","mysql","postgres","smtp","smb"]),
    "low":      lambda d: True,
}
RISK_ICON = {"critical":"[CRITICAL]","high":"[HIGH]","medium":"[MEDIUM]","low":"[LOW]"}

def risk_level(d):
    for level, check in RISK_RULES.items():
        if check(d): return level
    return "low"

def ensure_port(p):
    _ = findings[p]

SENSITIVE_PATHS=["/admin","/login","/wp-admin","/wp-login.php","/phpmyadmin","/.env",
                 "/backup","/api/v1","/console","/actuator/env","/.git/HEAD","/server-status"]

def sh(cmd, inp=None, timeout=30):
    try:
        r=subprocess.run(cmd,input=inp,capture_output=True,text=True,timeout=timeout,shell=True)
        return (r.stdout+r.stderr)[:2500]
    except subprocess.TimeoutExpired: return "(timed out)"
    except Exception as e: return f"(error: {e})"

def has(tool):
    r=subprocess.run(f"where {tool}",capture_output=True,text=True,shell=True)
    return r.returncode==0

def ollama_chat(messages):
    body=json.dumps({"model":model,"messages":messages,"stream":False}).encode()
    req=urllib.request.Request(f"{host}/api/chat",data=body,
                               headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=120) as r:
            content=json.loads(r.read())["message"]["content"]
            content=re.sub(r'<think>.*?</think>','',content,flags=re.DOTALL)
            content=re.sub(r'^.*?</think>\s*','',content,flags=re.DOTALL)
            content=re.sub(r'<think>.*$','',content,flags=re.DOTALL)
            return content.strip()
    except Exception as e:
        return f""

def tool_scan(port):
    ensure_port(port)
    if has("nmap"):
        out=sh(f"nmap -sV -sC -p {port} --open -T4 {target}",timeout=45)
        findings[port]["notes"].append(out[:200])
        for line in out.splitlines():
            if f"{port}/tcp" in line:
                parts=line.split()
                if len(parts)>=4:
                    findings[port]["service"]=parts[2]
                    findings[port]["version"]=" ".join(parts[3:])
        return out
    return f"nmap not found"

def tool_banner(port):
    ensure_port(port)
    out=sh(f"nmap -p {port} --script=banner {target}",timeout=15)
    b=out[:600] or "(no banner)"
    findings[port]["banner"]=b
    for m in re.findall(r'\$[126]\$\S+|[a-f0-9]{32,64}',b):
        if m not in findings[port]["hashes"]: findings[port]["hashes"].append(m)
    return b

def tool_http_probe(port, path="/"):
    ensure_port(port)
    scheme="https" if port in ("443","8443") else "http"
    out=sh(f'curl -sk --max-time 6 -i -L --max-redirs 2 {scheme}://{target}:{port}{path}')
    for m in re.findall(r'\$[126]\$\S+|[a-f0-9]{32,64}',out):
        if m not in findings[port]["hashes"]: findings[port]["hashes"].append(m)
    return out[:1500]

def tool_http_paths(port):
    ensure_port(port)
    scheme="https" if port in ("443","8443") else "http"
    found=[]
    for path in SENSITIVE_PATHS:
        out=sh(f'curl -sk --max-time 4 -o NUL -w "%{{http_code}}" {scheme}://{target}:{port}{path}')
        code=out.strip()
        if code not in ("404","000","","400"): found.append(f"{code}  {path}")
    findings[port]["paths_found"].extend(found)
    return "\n".join(found) if found else "no sensitive paths found"

def tool_try(service, port, user, passwd):
    ensure_port(port)
    s=service.lower(); res="failed"
    if s in ("http","https","web"):
        scheme="https" if port in ("443","8443") else "http"
        out=sh(f'curl -sk --max-time 4 -o NUL -w "%{{http_code}}" -u {user}:{passwd} {scheme}://{target}:{port}/')
        code=out.strip()
        res=f"HTTP {code} SUCCESS" if code in ("200","302","301","303") else "failed"
    elif s=="ftp":
        out=sh(f"curl -s --max-time 5 ftp://{user}:{passwd}@{target}/")
        res="LOGIN SUCCEEDED" if "530" not in out and out else "failed"
    elif s=="redis":
        out=sh(f'echo AUTH {passwd}\r\nPING\r\nQUIT | ncat {target} {port}',timeout=5)
        if "+OK" in out and "+PONG" in out:
            res=f"password '{passwd}' ACCEPTED"
        else:
            out2=sh(f'echo PING\r\nQUIT | ncat {target} {port}',timeout=5)
            if "+PONG" in out2:
                findings[port]["no_auth"]=True; res="NO AUTH REQUIRED"
    if "SUCCEEDED" in res or "ACCEPTED" in res or "SUCCESS" in res:
        cred=f"{user}:{passwd}"
        if cred not in findings[port]["creds_ok"]: findings[port]["creds_ok"].append(cred)
    return res

def tool_wordlist(service, port):
    ensure_port(port)
    hits=[]
    if service.lower()=="redis":
        out=sh(f'echo PING\r\nQUIT | ncat {target} {port}',timeout=5)
        if "+PONG" in out:
            findings[port]["no_auth"]=True
            return "CRITICAL: Redis has NO password"
    total=len(TOP_USERS)*len(TOP_PASSES); done=0; bar_w=30
    for user in TOP_USERS:
        for pw in TOP_PASSES:
            done+=1
            pct=done*100//total; filled=done*bar_w//total
            bar="\u2588"*filled+"\u2591"*(bar_w-filled)
            sys.stdout.write(f"  \033[2m[{bar}] {pct:3d}%  testing {service}/{user}\033[0m\r")
            sys.stdout.flush()
            res=tool_try(service,port,user,pw)
            if "SUCCEEDED" in res or "ACCEPTED" in res or "NO AUTH" in res:
                hits.append(f"  \u2713 {user}:{pw or '(empty)'}  \u2192  {res}")
                if len(hits)>=3: break
        if len(hits)>=3: break
    sys.stdout.write("  "+" "*60+"\r"); sys.stdout.flush()
    return "\n".join(hits) if hits else "no credentials from wordlist succeeded"

def tool_nmap_script(port, script):
    if not has("nmap"): return "nmap not installed"
    out=sh(f"nmap -p {port} --script={script} -T4 {target}",timeout=60)
    ensure_port(port)
    findings[port]["notes"].append(f"nmap {script}: {out[:200]}")
    return out

def tool_crack(h):
    h=h.strip()
    hf=tempfile.NamedTemporaryFile(mode='w',suffix='.hash',delete=False)
    hf.write(h+"\n"); hf.close()
    ht=""; flag=""
    if re.match(r'^[a-f0-9]{32}$',h,re.I):   ht="MD5";    flag="--hash-type=0"
    elif re.match(r'^[a-f0-9]{40}$',h,re.I): ht="SHA1";   flag="--hash-type=100"
    elif re.match(r'^[a-f0-9]{64}$',h,re.I): ht="SHA256"; flag="--hash-type=1400"
    elif re.match(r'^\$6\$',h):               ht="SHA512"; flag="--hash-type=1800"
    wl="C:\\rockyou.txt"
    out=""
    if has("hashcat") and flag and os.path.exists(wl):
        r=subprocess.run(f'hashcat {flag} {hf.name} {wl} --quiet --potfile-disable --outfile-format=2 --runtime=20',
            shell=True,capture_output=True,text=True,timeout=25)
        if r.returncode==0 and r.stdout.strip():
            out=f"CRACKED: {r.stdout.strip().splitlines()[-1]}"
    os.unlink(hf.name)
    result=out or f"could not crack — type: {ht or 'unknown'}"
    for p,d in findings.items():
        if h in d["hashes"] and out: d["cracked"].append(f"{h[:20]}... -> {out}")
    return result

def ai_report(case_file):
    now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    header=["="*62,
            f"  SECURITY REPORT  .  {target}  .  {now}",
            f"  Model: {model}",
            "="*62,""]
    port_lines=[]
    for port,data in sorted(findings.items(),key=lambda x:int(x[0]) if x[0].isdigit() else 0):
        rl=risk_level(data); svc=data["service"] or "unknown"
        ver=f" ({data['version']})" if data["version"] else ""
        issues=[]
        if data["no_auth"]: issues.append("NO PASSWORD")
        for c in data["creds_ok"]: issues.append(f"weak credential: {c}")
        for c in data["cracked"]: issues.append(f"hash cracked: {c}")
        if data["paths_found"]: issues.append(f"exposed paths: {', '.join(data['paths_found'][:3])}")
        status="; ".join(issues) if issues else "open"
        port_lines.append(f"  Port {port} - {svc.upper()}{ver}  {RISK_ICON[rl]}  {status}")
    case_text="\n\n".join(case_file) if case_file else "Initial scan only."
    report_msgs=[
        {"role":"system","content":(
            "You are a security analyst writing a penetration test report. "
            "Write in clear plain English that a non-technical person can understand. "
            "Do not use markdown # headers. Use plain section labels in ALL CAPS."
        )},
        {"role":"user","content":(
            f"Target: {target}\n\n"
            "Port overview:\n"+"\n".join(port_lines)+"\n\n"
            f"Full investigation log:\n{case_text[:5000]}\n\n"
            "Write a complete security report with exactly these four sections:\n"
            "EXECUTIVE SUMMARY\n"
            "FINDINGS (cover each port: service name, risk level, plain-English explanation)\n"
            "WHAT TO DO FIRST (numbered list, most critical action first)\n"
            "ADDITIONAL HARDENING (3-5 general recommendations)"
        )}
    ]
    body=ollama_chat(report_msgs)
    return "\n".join(header)+body+"\n"

# ── Agent (ReAct loop) ────────────────────────────────────
SYSTEM="""You are an autonomous security agent performing an authorized penetration test.

Each response MUST follow this exact two-line format:
Thought: <your reasoning about findings so far and what to do next>
Action: TOOL_NAME arg1 arg2

Available actions:
  SCAN_PORT <port>                 detailed version + script scan
  BANNER_GRAB <port>               grab raw service banner
  HTTP_PROBE <port> <path>         fetch a specific URL path
  HTTP_PATHS <port>                check common sensitive paths
  TRY_CREDS <svc> <port> <u> <p>  test a single credential
  WORDLIST <svc> <port>            brute-force common credentials
  NMAP_SCRIPT <port> <script>      run an nmap NSE script
  CRACK_HASH <hash>                crack a password hash
  REPORT                           write the final report (call when done)

Guidelines:
- SCAN_PORT and BANNER_GRAB each discovered port to identify services and versions
- WORDLIST any authentication service: ftp, redis, mysql, postgres, http
- HTTP_PATHS any web port (http or https)
- Follow leads: if a banner or response contains a hash, CRACK_HASH it
- When all services are thoroughly investigated, call Action: REPORT
"""

case_file=[]
msgs=[
    {"role":"system","content":SYSTEM},
    {"role":"user","content":(
        f"Target: {target}\n\nInitial port scan:\n{INITIAL}\n\n"
        "Investigate all discovered services thoroughly, then call Action: REPORT."
    )}
]

print(f"\n  {B}{C}Agent starting{R}  {D}target: {target}  model: {model}{R}\n",flush=True)

for line in INITIAL.splitlines():
    m=re.match(r'(\d+)/tcp\s+\S+\s+(\S*)\s*(.*)',line)
    if m:
        p,svc,ver=m.group(1),m.group(2),m.group(3).strip()
        ensure_port(p)
        if svc: findings[p]["service"]=svc
        if ver: findings[p]["version"]=ver

itr=0
while itr < MAX_IT:
    itr+=1
    sys.stdout.write(f"  {D}[{itr}/{MAX_IT}] reasoning...{R}   \r"); sys.stdout.flush()
    reply=ollama_chat(msgs)
    sys.stdout.write("  "+" "*50+"\r"); sys.stdout.flush()
    if not reply: break

    thought_m=re.search(r'Thought:\s*(.+?)(?=\nAction:|\Z)',reply,re.DOTALL|re.IGNORECASE)
    if thought_m:
        for tl in thought_m.group(1).strip().splitlines():
            tl=tl.strip()
            if tl: print(f"  {D}💭 {tl}{R}",flush=True)

    action_m=(re.search(r'Action:\s*(\S[^\n]*)',reply,re.IGNORECASE) or
              re.search(r'TOOL:\s*(\S[^\n]*)',reply))
    if not action_m: break

    tool_call=action_m.group(1).strip()
    tool_name=tool_call.split()[0].upper()
    args=tool_call.split()[1:]

    print(f"  {C}\u25b6{R}  {B}{tool_call}{R}",flush=True)

    if tool_name=="REPORT": break

    result="unknown tool"
    try:
        if   tool_name=="SCAN_PORT"   and args: result=tool_scan(args[0])
        elif tool_name=="BANNER_GRAB" and args: result=tool_banner(args[0])
        elif tool_name=="HTTP_PROBE"  and args: result=tool_http_probe(args[0],args[1] if len(args)>1 else "/")
        elif tool_name=="HTTP_PATHS"  and args: result=tool_http_paths(args[0])
        elif tool_name=="TRY_CREDS"   and len(args)>=4: result=tool_try(args[0],args[1],args[2],args[3])
        elif tool_name=="WORDLIST"    and len(args)>=2: result=tool_wordlist(args[0],args[1])
        elif tool_name=="NMAP_SCRIPT" and len(args)>=2: result=tool_nmap_script(args[0],args[1])
        elif tool_name=="CRACK_HASH"  and args: result=tool_crack(args[0])
    except Exception as e:
        result=f"tool error: {e}"

    short=result[:120]+("..." if len(result)>120 else "")
    print(f"  {D}{short}{R}",flush=True)

    case_file.append(f"[{tool_call}]\n{result[:1500]}")
    msgs.append({"role":"assistant","content":reply})
    msgs.append({"role":"user","content":f"Result:\n{result[:2000]}"})

print(f"\n  {B}{C}Writing report...{R}\n",flush=True)
report=ai_report(case_file)
print(report)
with open(log_path,"a",encoding="utf-8") as f:
    f.write(report)
'@

    $pyFile = "$env:TEMP\kp_attack_$(Get-Random).py"
    [System.IO.File]::WriteAllText($pyFile, $pyScript, (New-Object System.Text.UTF8Encoding $True))

    $logDir = "$env:ProgramData\killport"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

    $nmapOutput | & $py $pyFile $target $conf.ollama_host $conf.model $ATTACK_LOG

    Remove-Item $pyFile -ErrorAction SilentlyContinue
}

function Invoke-AttackDispatch($sub, $arg) {
    $subCmd = if ($sub) { $sub.ToLower() } else { "" }
    switch ($subCmd) {
        "config"   { Show-AttackConfig }
        "log"      { Show-AttackLog }
        "allports" {
            if (-not $arg) { wh "  Usage: killport attack allports <ip>" Yellow; Write-Host ""; return }
            Start-AttackRun $arg $true
        }
        ""         {
            Write-Host ""
            wh "  killport attack" Cyan
            Write-Rule
            Write-Host ""
            Write-Host "  killport attack <ip>              AI pentest (common ports)  (requires Ollama)"
            Write-Host "  killport attack allports <ip>     AI pentest (all 65535 ports)  (requires Ollama)"
            Write-Host "  killport config            configure Ollama host and model"
            Write-Host "  killport attack log               view last attack log"
            Write-Host ""
        }
        default    { Start-AttackRun $sub }
    }
}

# ── stress ───────────────────────────────────────────────────────────────────

function Invoke-StressRun($target) {
    if ($target -notmatch '^(.+):(\d+)$') {
        Write-Host ""; wh "  Usage: killport stress <ip:port>" Yellow; Write-Host ""; return
    }
    $ip = $Matches[1]; $port = [int]$Matches[2]
    $svc = switch ($port) { 80 {"http"} 8080 {"http"} 8000 {"http"} 3000 {"http"} 3001 {"http"}
                             443 {"https"} 8443 {"https"} 6379 {"redis"} default {"tcp"} }
    Write-Host ""
    wh "  killport stress" Cyan; wh "  authorized connection flood testing" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""
    Write-Host "  Target:   $target  (service: $svc)"
    Write-Host ""
    $dur = Read-Host "  Duration in seconds [default 30]"
    if ($dur -notmatch '^\d+$' -or [int]$dur -lt 1) { $dur = 30 }
    $dur = [int]$dur
    Write-Host ""
    wh "  ⚠  This will flood ${ip}:${port} for ${dur}s at up to 20 concurrent connections." Yellow
    wh "  Only test systems you own or have written authorization to test." DarkGray
    Write-Host ""
    $confirm = Read-Host "  Type yes to confirm"
    if ($confirm -ne "yes") { Write-Host ""; wh "  Aborted." DarkGray; Write-Host ""; return }

    $py = Get-CmdPath python
    if (-not $py) { $py = Get-CmdPath python3 }
    if (-not $py) { wh "  Python not found. Install Python 3 to use stress testing." Yellow; return }

    $logDir = "$env:ProgramData\killport"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $logPath = "$logDir\attack_log.txt"

    $pyScript = @'
import sys,socket,threading,time,datetime
try: import ssl as _ssl; _HAS_SSL=True
except: _HAS_SSL=False
TARGET=sys.argv[1]; PORT=int(sys.argv[2]); SVC=sys.argv[3]
SECS=int(sys.argv[4]); THREADS=int(sys.argv[5]); LOG=sys.argv[6]
sent=0; errs=0; peak=0; lock=threading.Lock(); stop=threading.Event()
B="\033[1m"; C="\033[0;36m"; D="\033[2m"; G="\033[0;32m"; RE="\033[0;31m"; R="\033[0m"
def worker():
    global sent,errs
    while not stop.is_set():
        try:
            s=socket.socket(socket.AF_INET,socket.SOCK_STREAM); s.settimeout(3)
            if SVC=="https" and _HAS_SSL:
                ctx=_ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=_ssl.CERT_NONE
                s=ctx.wrap_socket(s,server_hostname=TARGET)
            s.connect((TARGET,PORT))
            if SVC in ("http","https"):
                s.sendall((f"GET / HTTP/1.1\r\nHost: {TARGET}\r\nUser-Agent: killport-stress/1.0\r\nConnection: close\r\n\r\n").encode())
                s.recv(512)
            elif SVC=="redis": s.sendall(b"PING\r\n"); s.recv(32)
            s.close()
            with lock: sent+=1
        except:
            with lock: errs+=1
def stat_loop():
    global peak
    SP=["|-", "/|", "-|", "\\|"]
    start=time.time(); prev=0; tick=0
    while not stop.is_set():
        elapsed=time.time()-start; rem=max(0,SECS-elapsed)
        with lock: s=sent; e=errs
        ps=s-prev; prev=s
        with lock:
            if ps>peak: peak=ps
        avg=s/max(elapsed,0.1)
        pct=min(100,int(elapsed/SECS*100)); bw=24
        bar="="*int(pct*bw/100)+"-"*(bw-int(pct*bw/100))
        sys.stdout.write(f"\r  {SP[tick%len(SP)]}  [{bar}]  {B}{s:,}{R} req  {avg:.0f}/s  {e} err  {rem:.0f}s left   ")
        sys.stdout.flush(); tick+=1; time.sleep(1)
ts=[threading.Thread(target=worker,daemon=True) for _ in range(THREADS)]
for t in ts: t.start()
threading.Thread(target=stat_loop,daemon=True).start()
time.sleep(SECS); stop.set(); time.sleep(0.5)
sys.stdout.write("\r"+" "*80+"\r"); sys.stdout.flush()
with lock: total=sent; total_err=errs; pk=peak
avg=total/max(SECS,1); ep=total_err*100//(total+total_err) if (total+total_err) else 0
still_up=False
try:
    cs=socket.socket(socket.AF_INET,socket.SOCK_STREAM); cs.settimeout(3); cs.connect((TARGET,PORT)); cs.close(); still_up=True
except: pass
st_txt="ONLINE - still responding" if still_up else "NOT RESPONDING - may be down"
now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
sep="="*54
report=(f"{sep}\n  STRESS TEST  {TARGET}:{PORT}  {now}\n{sep}\n"
        f"  Service:   {SVC}\n  Duration:  {SECS}s  Threads: {THREADS}\n"
        f"  Requests:  {total:,}  ({avg:.0f}/s avg,  {pk}/s peak)\n"
        f"  Errors:    {total_err:,}  ({ep}%)\n  After:     {st_txt}\n{sep}\n")
print(f"  {sep}"); print(f"  STRESS TEST COMPLETE"); print(f"  {sep}")
print(f"  Service:   {SVC}  ({TARGET}:{PORT})")
print(f"  Duration:  {SECS}s  Threads: {THREADS}")
print(f"  Requests:  {B}{total:,}{R}  ({avg:.0f}/s avg  {pk}/s peak)")
print(f"  Errors:    {total_err:,}  ({ep}%)")
print(f"  After:     {st_txt}")
print(f"  {sep}")
with open(LOG,"a",encoding="utf-8") as f: f.write(report)
'@
    $pyFile = "$env:TEMP\kp_stress_$(Get-Random).py"
    [System.IO.File]::WriteAllText($pyFile, $pyScript, (New-Object System.Text.UTF8Encoding $true))
    try { & $py $pyFile $ip $port $svc $dur 20 $logPath } finally { Remove-Item $pyFile -ErrorAction SilentlyContinue }
    Write-Host ""
    wh "  Logged to: $logPath" DarkGray; Write-Host ""
}

function Invoke-StressDispatch($sub) {
    if (-not $sub) {
        Write-Host ""
        wh "  killport stress" Cyan; wh "  authorized connection flood testing" DarkGray; Write-Host ""
        Write-Rule; Write-Host ""
        Write-Host "  killport stress <ip:port>     flood test a single service"
        Write-Host ""
        wh "  Examples:" DarkGray
        wh "    killport stress 192.168.1.10:80     HTTP flood" DarkGray
        wh "    killport stress 192.168.1.10:22     TCP connection flood" DarkGray
        wh "    killport stress 192.168.1.10:6379   Redis PING flood" DarkGray
        Write-Host ""
        wh "  Requires authorization. Only test systems you own or have permission to test." DarkGray
        Write-Host ""; return
    }
    Invoke-StressRun $sub
}

# ── scan ─────────────────────────────────────────────────────────────────────

function Invoke-Scan($target, $mode) {
    if (-not $target) { Write-Host ""; wh "  Usage: killport scan <ip> [all]" Yellow; Write-Host ""; return }
    $nmap = Get-CmdPath nmap
    if (-not $nmap) { wh "  nmap required. Download from https://nmap.org/download.html" Yellow; return }
    Write-Host ""
    wh "  killport scan" Cyan -nl; Write-Host "  $target"
    Write-Rule; Write-Host ""
    $args_ = @("-sV","-T4","--open")
    if ($mode -eq "all") { $args_ = @("-p-") + $args_; wh "  Scanning all 65535 ports - this may take several minutes..." DarkGray }
    else { wh "  Scanning common ports..." DarkGray }
    Write-Host ""
    $raw = & $nmap @args_ $target 2>$null | Out-String
    $found = $false
    wh ("  {0,-7}  {1,-18}  {2}" -f "PORT","SERVICE","VERSION") DarkGray
    wh ("  " + ("-"*54)) DarkGray
    foreach ($line in $raw -split "`n") {
        if ($line -match '^(\d+)/tcp\s+open\s+(\S+)\s*(.*)') {
            $p=$Matches[1]; $s=$Matches[2]; $v=$Matches[3].Trim()
            wh ("  {0,-7}" -f $p) Green -nl; Write-Host ("  {0,-18}  " -f $s) -NoNewline; wh $v DarkGray
            $found = $true
        }
    }
    if (-not $found) { wh "  No open ports found." DarkGray }
    $lat = [regex]::Match($raw,'[\d.]+ s latency').Value
    Write-Host ""
    if ($lat) { wh "  Host latency: $lat" DarkGray; Write-Host "" }
}

# ── watch ────────────────────────────────────────────────────────────────────

function Watch-PortConnections($port) {
    if (-not $port) { Write-Host ""; wh "  Usage: killport watch <port>" Yellow; Write-Host ""; return }
    Write-Host ""
    wh "  killport watch" Cyan -nl; Write-Host "  port $port  (Ctrl+C to stop)"
    Write-Rule; Write-Host ""
    wh ("  {0,-10}  {1,-26}  {2,-14}  {3}" -f "TIME","REMOTE","STATE","PROCESS") DarkGray
    wh ("  " + ("-"*62)) DarkGray
    $seen = @{}
    try {
        while ($true) {
            $conns = netstat -n 2>$null | Where-Object { $_ -match "\b$port\b" }
            foreach ($line in $conns) {
                $parts = $line.Trim() -split '\s+'
                if ($parts.Count -lt 4) { continue }
                $remote = $parts[2]; $state = if ($parts.Count -ge 4) { $parts[3] } else { "-" }
                $key = "$remote|$state"
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $ts = (Get-Date).ToString("HH:mm:ss")
                    $col = switch ($state) { "CLOSE_WAIT" {"Yellow"} "TIME_WAIT" {"Yellow"} "SYN_RECEIVED" {"Red"} default {"Green"} }
                    Write-Host ("  {0,-10}  {1,-26}  " -f $ts,$remote) -NoNewline
                    wh ("{0,-14}" -f $state) $col -nl; Write-Host ""
                }
            }
            Start-Sleep -Milliseconds 500
        }
    } catch { wh "  Stopped." DarkGray; Write-Host "" }
}

# ── cert ─────────────────────────────────────────────────────────────────────

function Check-Cert($target) {
    if (-not $target) { Write-Host ""; wh "  Usage: killport cert <host:port> or <domain>" Yellow; Write-Host ""; return }
    $host_ = if ($target -match '^(.+):(\d+)$') { $Matches[1] } else { $target }
    $port_ = if ($target -match ':(\d+)$') { [int]$Matches[1] } else { 443 }
    Write-Host ""
    wh "  killport cert" Cyan -nl; wh "  ${host_}:${port_}" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""
    wh "  Connecting..." DarkGray; Write-Host ""
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient($host_, $port_)
        $ssl = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false,
            { param($s,$c,$ch,$e) $true })
        $ssl.AuthenticateAsClient($host_)
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$ssl.RemoteCertificate
        $ssl.Dispose(); $tcp.Dispose()

        $subject  = $cert.Subject
        $issuer   = $cert.Issuer
        $notAfter = $cert.NotAfter
        $daysLeft = ([int](($notAfter - (Get-Date)).TotalDays))
        $expCol   = if ($daysLeft -lt 30) {"Red"} elseif ($daysLeft -lt 90) {"Yellow"} else {"Green"}

        wh "  Subject :" -nl; wh "  $subject" DarkGray
        wh "  Issuer  :" -nl; wh "  $issuer" DarkGray
        Write-Host "  Expires : " -NoNewline
        wh "$($notAfter.ToString('yyyy-MM-dd'))  ($daysLeft days)" $expCol

        $sanExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Subject Alternative Name" }
        if ($sanExt) {
            wh "  SANs    :" DarkGray
            $sanExt.Format($true) -split "`n" | Where-Object { $_ -match 'DNS Name' } | ForEach-Object {
                wh ("    " + ($_ -replace 'DNS Name=','').Trim()) DarkGray
            }
        }
        wh "  Protocol: $($ssl.SslProtocol)" DarkGray
        wh "  Cipher  : $($ssl.CipherAlgorithm)" DarkGray
    } catch {
        wh "  Could not retrieve certificate from ${host_}:${port_} — $_" Red
    }
    Write-Host ""
}

# ── sniff ────────────────────────────────────────────────────────────────────

function Sniff-Port($target) {
    if (-not $target) {
        Write-Host ""
        wh "  Usage: killport sniff <port>  or  killport sniff <ip:port>" Yellow
        Write-Host ""; return
    }
    $ip_ = $null; $port_ = $null; $label = $null
    if ($target -match '^(.+):(\d+)$') {
        $ip_ = $Matches[1]; $port_ = $Matches[2]; $label = "${ip_}:${port_}"
    } else {
        $port_ = $target; $label = "port $target"
    }
    Write-Host ""
    wh "  killport sniff" Cyan -nl; Write-Host "  $label  (Ctrl+C to stop)"
    Write-Rule; Write-Host ""
    $pktmon = Get-CmdPath pktmon
    if (-not $pktmon) {
        wh "  pktmon not found. Requires Windows 10 1809+ (run as Administrator)." Yellow
        wh "  Alternative: Wireshark (https://www.wireshark.org)" DarkGray
        Write-Host ""; return
    }
    if ($ip_) { wh "  Filter: host $ip_ and port $port_. Requires Administrator." DarkGray }
    else       { wh "  Filter: port $port_. Requires Administrator." DarkGray }
    wh "  Press Ctrl+C to stop." DarkGray; Write-Host ""
    try {
        if ($ip_) { & pktmon filter add -p $port_ --ip-address $ip_ 2>$null | Out-Null }
        else       { & pktmon filter add -p $port_ 2>$null | Out-Null }
        & pktmon start --etw -l real-time 2>$null | ForEach-Object {
            $ts = (Get-Date).ToString("HH:mm:ss.fff")
            wh "  $ts  " DarkGray -nl; Write-Host $_
        }
    } finally {
        & pktmon stop 2>$null | Out-Null
        & pktmon filter remove 2>$null | Out-Null
        Write-Host ""
    }
}

# ── vuln ─────────────────────────────────────────────────────────────────────

function Check-Vuln($target) {
    if (-not $target -or $target -notmatch ':') {
        Write-Host ""; wh "  Usage: killport vuln <ip:port>" Yellow; Write-Host ""; return
    }
    $host_ = $target -replace ':.*'
    $port_ = $target -replace '.*:'
    Write-Host ""
    wh "  killport vuln" Cyan -nl; wh "  $target" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""
    $nmap = Get-CmdPath nmap
    if (-not $nmap) { wh "  nmap required for version detection. Download from https://nmap.org" Yellow; return }
    wh "  Detecting service on port $port_..." DarkGray; Write-Host ""
    $raw = & $nmap -sV -p $port_ --open -T4 $host_ 2>$null | Out-String
    $svcLine = ($raw -split "`n" | Where-Object { $_ -match "${port_}/tcp" } | Select-Object -First 1)
    if (-not $svcLine) { wh "  Could not detect service on ${host_}:${port_}" Yellow; Write-Host ""; return }
    $parts = $svcLine.Trim() -split '\s+',5
    $svc = $parts[2]; $ver = if ($parts.Count -ge 4) { $parts[3..($parts.Count-1)] -join " " } else { "unknown" }
    if (-not $svc -or $svc -eq "open") { wh "  Could not detect service on ${host_}:${port_}" Yellow; Write-Host ""; return }
    wh "  Service:" -nl; Write-Host "  $svc"
    wh "  Version:" -nl; wh "  $ver" DarkGray; Write-Host ""
    wh "  Querying NVD database..." DarkGray; Write-Host ""

    $py = Get-CmdPath python
    if (-not $py) { $py = Get-CmdPath python3 }
    if (-not $py) { wh "  Python required for CVE lookup." Yellow; return }

    $pyScript = @'
import sys,json,urllib.request,urllib.parse
svc=sys.argv[1]; ver=sys.argv[2]
query=urllib.parse.quote(f"{svc} {ver.split()[0]}")
B="\033[1m"; D="\033[2m"; G="\033[0;32m"; Y="\033[0;33m"; RE="\033[0;31m"; R="\033[0m"
SC={"CRITICAL":RE,"HIGH":RE,"MEDIUM":Y,"LOW":G,"NONE":D}
try:
    url=f"https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch={query}&resultsPerPage=10"
    req=urllib.request.Request(url,headers={"User-Agent":"killport/1.0"})
    with urllib.request.urlopen(req,timeout=12) as r: obj=json.loads(r.read())
    vulns=obj.get("vulnerabilities",[]); total=obj.get("totalResults",len(vulns))
    if not vulns: print(f"  {G}No CVEs found for this service/version.{R}"); sys.exit(0)
    print(f"  {B}{total}{R} CVE(s) found - showing top {len(vulns)}:\n")
    for v in vulns:
        c=v.get("cve",{})
        cid=c.get("id","?")
        desc=next((d["value"] for d in c.get("descriptions",[]) if d.get("lang")=="en"),"")[:120]
        sev,score="UNKNOWN",""
        for mk in ("cvssMetricV31","cvssMetricV30","cvssMetricV2"):
            if mk in c.get("metrics",{}):
                m0=c["metrics"][mk][0]; cd=m0.get("cvssData",{})
                sev=cd.get("baseSeverity",m0.get("baseSeverity","?")); score=str(cd.get("baseScore",""))
                break
        sc=SC.get(sev.upper(),D)
        print(f"  {B}{cid}{R}  {sc}[{sev}  {score}]{R}")
        print(f"  {D}{desc}{'...' if len(desc)==120 else ''}{R}\n")
except Exception as e: print(f"  Error: {e}")
'@
    $pyFile = "$env:TEMP\kp_vuln_$(Get-Random).py"
    [System.IO.File]::WriteAllText($pyFile, $pyScript, (New-Object System.Text.UTF8Encoding $true))
    try { & $py $pyFile $svc ($ver -replace '\s+',' ') } finally { Remove-Item $pyFile -ErrorAction SilentlyContinue }
    Write-Host ""
}

# ── fix ──────────────────────────────────────────────────────────────────────

function Invoke-Fix($target) {
    if (-not $target -or $target -notmatch ':') {
        Write-Host ""; wh "  Usage: killport fix <ip:port>" Yellow; Write-Host ""; return
    }
    $ip_  = $target -replace ':.*'
    $port_= $target -replace '.*:'

    $nmap = Get-CmdPath nmap
    if (-not $nmap) { wh "  nmap required. Download from https://nmap.org" Yellow; return }

    Write-Host ""
    wh "  killport fix" Cyan -nl; wh "  $target" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""
    wh "  Detecting service on port $port_..." DarkGray; Write-Host ""

    $raw = & $nmap -sV -p $port_ --open -T4 $ip_ 2>$null | Out-String
    $svcLine = ($raw -split "`n" | Where-Object { $_ -match "${port_}/tcp" } | Select-Object -First 1)
    if (-not $svcLine) { wh "  Could not detect service on ${ip_}:${port_}" Yellow; Write-Host ""; return }
    $parts = $svcLine.Trim() -split '\s+',5
    $svc = $parts[2]; $ver = if ($parts.Count -ge 4) { ($parts[3..($parts.Count-1)] -join " ").Trim() } else { "" }
    if (-not $svc -or $svc -eq "open") { wh "  Could not detect service." Yellow; Write-Host ""; return }

    wh "  Service:" -nl; Write-Host "  $svc"
    wh "  Version:" -nl; wh "  $ver" DarkGray; Write-Host ""

    # Detect if local
    $isLocal = ($ip_ -eq "127.0.0.1" -or $ip_ -eq "localhost" -or $ip_ -eq "::1")
    if (-not $isLocal) {
        $ownIPs = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        $isLocal = $ownIPs -contains $ip_
    }
    if ($isLocal) { wh "  ✓  Target is this machine — can apply fixes directly." Green }
    else           { wh "  Remote target — will generate a fix script to copy over." DarkGray }
    Write-Host ""

    # Load Ollama config
    $confPath = "$env:ProgramData\killport\attack.conf"
    $ollamaHost = "localhost:11434"; $model = ""
    if (Test-Path $confPath) {
        Get-Content $confPath | ForEach-Object {
            if ($_ -match '^OLLAMA_HOST=(.+)') { $ollamaHost = $Matches[1].Trim() }
            if ($_ -match '^MODEL=(.+)')       { $model      = $Matches[1].Trim() }
        }
    }

    $py = Get-CmdPath python
    if (-not $py) { $py = Get-CmdPath python3 }
    if (-not $py) { wh "  Python required for fix generation." Yellow; return }

    $logDir = "$env:ProgramData\killport"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $scriptOut = "$env:TEMP\kp_fix_apply_$(Get-Random).ps1"

    $pyScript = @'
import sys,json,subprocess,os,re,datetime
try: import urllib.request,urllib.parse; HAS_NET=True
except: HAS_NET=False

IP=sys.argv[1]; PORT=sys.argv[2]; SVC=sys.argv[3]; VER=sys.argv[4]
IS_LOCAL=sys.argv[5]=="1"; OLLAMA=sys.argv[6]; MODEL=sys.argv[7]; SCRIPT_OUT=sys.argv[8]

B="\033[1m"; C="\033[0;36m"; D="\033[2m"; G="\033[0;32m"
Y="\033[0;33m"; RE="\033[0;31m"; R="\033[0m"
SC={"CRITICAL":RE,"HIGH":RE,"MEDIUM":Y,"LOW":G,"NONE":D}

cvelist=[]
if HAS_NET:
    try:
        print(f"  {D}Querying NVD database...{R}",flush=True)
        kw=f"{SVC} {VER.split()[0]}" if VER else SVC
        query=urllib.parse.quote(kw)
        url=f"https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch={query}&resultsPerPage=5"
        req=urllib.request.Request(url,headers={"User-Agent":"killport/1.0"})
        with urllib.request.urlopen(req,timeout=12) as r: obj=json.loads(r.read())
        vulns=obj.get("vulnerabilities",[]); total=obj.get("totalResults",len(vulns))
        if vulns:
            print(f"\n  {B}{total}{R} CVE(s) - top {len(vulns)} shown:\n")
            for v in vulns:
                c=v.get("cve",{})
                cid=c.get("id","?")
                desc=next((d["value"] for d in c.get("descriptions",[]) if d.get("lang")=="en"),"")[:100]
                sev,score="UNKNOWN",""
                for mk in ("cvssMetricV31","cvssMetricV30","cvssMetricV2"):
                    if mk in c.get("metrics",{}):
                        m0=c["metrics"][mk][0]; cd=m0.get("cvssData",{})
                        sev=cd.get("baseSeverity",m0.get("baseSeverity","?")); score=str(cd.get("baseScore",""))
                        break
                sc=SC.get(sev.upper(),D)
                print(f"  {B}{cid}{R}  {sc}[{sev}  {score}]{R}")
                print(f"  {D}{desc}{'...' if len(desc)==100 else ''}{R}\n")
                cvelist.append(f"{cid} [{sev} {score}]: {desc}")
    except Exception as e:
        print(f"  {Y}NVD unavailable: {e}{R}\n")

def gen_script():
    L=["# killport fix script (PowerShell)",
       f"# Service: {SVC} {VER}  Target: {IP}:{PORT}",
       f"# Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}",
       "","function log($m){ Write-Host \"  [fix] $m\" }",
       "function warn($m){ Write-Host \"  [!]  $m\" -ForegroundColor Yellow }",""]
    s=SVC.lower()
    if "ssh" in s or s=="openssh":
        L+=[
            "log 'Hardening OpenSSH for Windows (OpenSSH Server)'",
            "$conf = \"$env:ProgramData\\ssh\\sshd_config\"",
            "if (-not (Test-Path $conf)) { warn 'sshd_config not found. Install OpenSSH Server first.'; exit 1 }",
            "Copy-Item $conf \"${conf}.bak\" -Force",
            "function Set-SshdOpt($key,$val) {",
            "  $c=Get-Content $conf",
            "  if ($c -match \"^#?\\s*$key\\s\") { $c=$c -replace \"^#?\\s*$key\\s.*\",\"$key $val\" }",
            "  else { $c+=\"$key $val\" }",
            "  Set-Content $conf $c",
            "}",
            "Set-SshdOpt 'PermitRootLogin' 'no'",
            "Set-SshdOpt 'MaxAuthTries' '3'",
            "Set-SshdOpt 'X11Forwarding' 'no'",
            "Set-SshdOpt 'PermitEmptyPasswords' 'no'",
            "Set-SshdOpt 'LoginGraceTime' '30'",
            "Set-SshdOpt 'ClientAliveInterval' '300'",
            "Restart-Service sshd -ErrorAction SilentlyContinue",
            "log 'SSH hardened and restarted'",
            "# Upgrade via winget",
            "winget upgrade --id Microsoft.OpenSSH.Beta -e 2>$null | Out-Null",
            "log 'OpenSSH upgrade attempted via winget'",
        ]
    elif "redis" in s:
        L+=[
            "log 'Hardening Redis...'",
            "$conf = (Get-ChildItem 'C:\\','C:\\Program Files\\Redis' -Filter redis.conf -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName",
            "if (-not $conf) { warn 'redis.conf not found'; exit 1 }",
            "Copy-Item $conf \"${conf}.bak\" -Force",
            "$c = Get-Content $conf",
            "$c = $c -replace '^bind .*','bind 127.0.0.1'",
            "if (-not ($c -match '^requirepass')) {",
            "  Add-Type -AssemblyName System.Web",
            "  $pass = [System.Web.Security.Membership]::GeneratePassword(32,4)",
            "  $c += \"requirepass $pass\"",
            "  warn \"Redis password set to: $pass  - save this now\"",
            "}",
            "foreach ($cmd in @('FLUSHALL','FLUSHDB','CONFIG','DEBUG')) {",
            "  if (-not ($c -match \"rename-command $cmd\")) { $c += \"rename-command $cmd `\"`\"\" }",
            "}",
            "Set-Content $conf $c",
            "Restart-Service Redis -ErrorAction SilentlyContinue",
            "log 'Redis hardened and restarted'",
        ]
    elif "mysql" in s or "mariadb" in s:
        L+=[
            "log 'Hardening MySQL...'",
            "$sql = @'",
            "DELETE FROM mysql.user WHERE User='';",
            "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');",
            "DROP DATABASE IF EXISTS test;",
            "FLUSH PRIVILEGES;",
            "'@",
            "& mysql -u root -e $sql 2>$null",
            "log 'MySQL: removed anonymous users and test database'",
            "winget upgrade --id Oracle.MySQL -e 2>$null | Out-Null",
            "log 'MySQL upgrade attempted via winget'",
        ]
    elif "http" in s or "nginx" in s or "apache" in s or "iis" in s:
        L+=[
            "log 'Adding IIS security headers...'",
            "Import-Module WebAdministration -ErrorAction SilentlyContinue",
            "$headers = @{",
            "  'X-Frame-Options'='SAMEORIGIN';",
            "  'X-Content-Type-Options'='nosniff';",
            "  'X-XSS-Protection'='1; mode=block';",
            "  'Strict-Transport-Security'='max-age=31536000'",
            "}",
            "foreach ($h in $headers.GetEnumerator()) {",
            "  try {",
            "    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter 'system.webServer/httpProtocol/customHeaders' -name '.' -value @{name=$h.Key;value=$h.Value} -ErrorAction Stop",
            "    log \"Added header: $($h.Key)\"",
            "  } catch { warn \"Could not add $($h.Key) - may already exist\" }",
            "}",
        ]
    elif "ftp" in s:
        L+=[
            "warn 'FTP is plaintext - disabling'",
            "Stop-Service ftpsvc -ErrorAction SilentlyContinue",
            "Set-Service ftpsvc -StartupType Disabled -ErrorAction SilentlyContinue",
            "log 'FTP disabled - use SFTP instead'",
        ]
    else:
        L+=[
            f"warn 'No specific template for {SVC} - attempting generic upgrade'",
            f"winget upgrade --id {SVC} -e 2>$null | Out-Null",
            "log 'Generic upgrade attempted via winget'",
        ]
    L+=["","log 'Fix script completed'",""]
    return "\n".join(L)

script_body=gen_script()
with open(SCRIPT_OUT,"w",encoding="utf-8") as f: f.write(script_body)

print(f"\n\033[0;36m  ────────────────────────────────────────────\033[0m")
print(f"  \033[1m\033[0;36mAI Remediation Advice\033[0m\n")
cve_text="\n".join(cvelist[:5]) if cvelist else "(no CVE data)"
prompt=(f"Service: {SVC} {VER}\nTarget: {IP}:{PORT}\n\nTop CVEs:\n{cve_text}\n\n"
        f"Give specific remediation in exactly 3 labeled sections:\n"
        f"UPGRADE: exact command to upgrade {SVC} on Windows\n"
        f"CONFIG: top 4 config hardening settings with exact values\n"
        f"NETWORK: Windows Firewall (netsh) commands to restrict access to port {PORT}\n\n"
        f"Be concise. No preamble. No markdown. No code fences. No concluding paragraph. Stop after NETWORK section. Version-specific where possible.")
if MODEL:
    try:
        payload=json.dumps({"model":MODEL,"think":False,"messages":[
            {"role":"system","content":"You are a security expert. Output ONLY exact commands and config values. No reasoning. No thinking. No explanations. Just the commands."},
            {"role":"user","content":prompt}
        ],"stream":True,"options":{"temperature":0}})
        proc=subprocess.Popen(["curl","-sN",f"http://{OLLAMA}/api/chat",
             "-H","Content-Type: application/json","--data-binary",payload],
            stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
        SP=["|-","/|","-|","\\|"]
        full=""; tok=0; in_think=False
        for raw in iter(proc.stdout.readline,""):
            try:
                obj=json.loads(raw.strip())
                t=obj.get("message",{}).get("content","")
                if t:
                    full+=t; tok+=1
                    if "<think>" in t: in_think=True
                    if "</think>" in t: in_think=False
                    lbl="thinking" if in_think else "generating"
                    sys.stdout.write(f"\r  {SP[tok%len(SP)]}  {tok} tokens  [{lbl}]   ")
                    sys.stdout.flush()
                if obj.get("done",False): break
            except: pass
        proc.wait()
        sys.stdout.write("\r"+" "*80+"\r\n"); sys.stdout.flush()
        full=re.sub(r'<think>.*?</think>','',full,flags=re.DOTALL)
        full=re.sub(r'^.*?</think>\s*','',full,flags=re.DOTALL)
        full=re.sub(r'<think>.*','',full,flags=re.DOTALL)
        full=re.sub(r'```\w*','',full)
        m=re.search(r'^(UPGRADE|CONFIG|NETWORK)[:\s]',full,re.MULTILINE|re.IGNORECASE)
        if m: full=full[m.start():]
        lines=full.splitlines()
        last_cmd=0
        for i,l in enumerate(lines):
            s=l.strip()
            if s and (s.startswith('#') or re.match(r'^(UPGRADE|CONFIG|NETWORK)[:\s]',s,re.I)
                      or any(w in s for w in ('netsh','Set-','Add-','Remove-','New-','sudo','=','Protocol','Permit','Allow','Deny','Max','Log','Cipher','Port ','ssh','sshd','sc ','reg ','bcdedit'))):
                last_cmd=i
        full='\n'.join(lines[:last_cmd+1]).strip()
        if full:
            for line in full.splitlines():
                l=line.rstrip()
                if re.match(r'^(UPGRADE|CONFIG|NETWORK)[:\s]',l,re.I):
                    print(f"\n  \033[1m\033[0;36m{l}\033[0m")
                elif l.startswith("  ") or l.startswith("\t"):
                    print(f"  \033[2m{l}\033[0m")
                elif l: print(f"  {l}")
        else:
            print("  (no AI response - is Ollama running?)")
    except Exception as e:
        print(f"  AI unavailable: {e}")
else:
    print("  No model configured - run: killport config")

print(f"\n\033[0;36m  ────────────────────────────────────────────\033[0m")
'@
    $pyFile = "$env:TEMP\kp_fix_$(Get-Random).py"
    [System.IO.File]::WriteAllText($pyFile, $pyScript, (New-Object System.Text.UTF8Encoding $true))
    try {
        & $py $pyFile $ip_ $port_ $svc $ver ([int]$isLocal) $ollamaHost $model $scriptOut
    } finally {
        Remove-Item $pyFile -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $scriptOut) -or (Get-Item $scriptOut).Length -eq 0) {
        wh "  Fix script generation failed." Yellow; Write-Host ""; return
    }

    if ($isLocal) {
        Write-Host ""
        $ans = Read-Host "  Apply these fixes now? (requires Admin)  [yes/N]"
        if ($ans -eq "yes") {
            Write-Rule; Write-Host ""
            & powershell -ExecutionPolicy Bypass -File $scriptOut
            Write-Host ""; Write-Rule
            wh "  ✓  Fixes applied.  Verify with: killport vuln $target" Green
        } else {
            wh "  Fix script saved to: $scriptOut" DarkGray
            wh "  Run manually:  powershell -ExecutionPolicy Bypass -File `"$scriptOut`"" DarkGray
        }
    } else {
        wh "  Fix script saved to: $scriptOut" DarkGray
        Write-Host ""
        wh "  Copy to remote machine and run:" DarkGray
        wh "  scp `"$scriptOut`" user@${ip_}:C:\fix.ps1" -nl
        wh "  ssh user@${ip_} 'powershell -ExecutionPolicy Bypass -File C:\fix.ps1'" -nl
    }
    Write-Host ""
}

function Invoke-FixDispatch($sub) {
    if (-not $sub) {
        Write-Host ""
        wh "  killport fix" Cyan -nl; wh "  detect and fix service vulnerabilities" DarkGray; Write-Host ""
        Write-Rule; Write-Host ""
        Write-Host "  killport fix <ip:port>     detect vulnerabilities and generate/apply a fix  (requires Ollama)"
        Write-Host ""
        wh "  Examples:" DarkGray
        wh "    killport fix 192.168.1.10:22     harden SSH" DarkGray
        wh "    killport fix 192.168.1.10:6379   harden Redis" DarkGray
        wh "    killport fix 127.0.0.1:3306      harden MySQL locally" DarkGray
        Write-Host ""
        wh "  Supports: SSH, Redis, MySQL, HTTP/IIS, FTP" DarkGray
        Write-Host ""; return
    }
    Invoke-Fix $sub
}

# ── audit ────────────────────────────────────────────────────────────────────

function Audit-Firewall {
    Write-Host ""
    wh "  killport audit" Cyan -nl; wh "  firewall rule review" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""
    wh "  Windows Firewall rules (inbound, enabled):" DarkGray; Write-Host ""

    $rules = $null
    try {
        Write-Host -NoNewline "  Loading firewall rules..."
        $rules = Get-NetFirewallRule -Direction Inbound -Enabled True -ErrorAction Stop
        Write-Host "`r  $($rules.Count) inbound rules loaded.        "
    } catch {
        try {
            $raw = netsh advfirewall firewall show rule name=all dir=in 2>$null
            Write-Host ($raw | Out-String)
            return
        } catch { wh "  Could not retrieve firewall rules. Try running as Administrator." Yellow; Write-Host ""; return }
    }
    if (-not $rules) { wh "  No enabled inbound rules found." DarkGray; Write-Host ""; return }

    $dangerPorts = @{ 3306="MySQL"; 5432="PostgreSQL"; 6379="Redis"; 27017="MongoDB"; 9200="Elasticsearch"; 11211="Memcached" }
    $allowRules  = @($rules | Where-Object { $_.Action -eq "Allow" })
    $total       = $allowRules.Count
    $findings    = 0
    $i           = 0

    Write-Host ""
    foreach ($r in $allowRules) {
        $i++
        Write-Host -NoNewline ("`r  Checking rule $i / $total ...   ")
        $filter    = $r | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
        $localPort = $filter.LocalPort -as [int]
        if ($localPort -and $dangerPorts.ContainsKey($localPort)) {
            Write-Host ""
            wh "  ⚠  Port $localPort ($($dangerPorts[$localPort])) is allowed inbound — confirm restricted to trusted IPs." Yellow
            $findings++
        }
    }
    Write-Host ("`r  Checked $total allow rules.          ")
    Write-Host ""

    $allowAll = $rules | Where-Object { $_.Action -eq "Allow" -and $_.DisplayName -match "All|Any" }
    if ($allowAll) { wh "  ⚠  Broad allow-all rules detected — review these carefully." Yellow; $findings++ }

    $blockCount = ($rules | Where-Object { $_.Action -eq "Block" }).Count
    if ($blockCount -gt 0) { wh "  ✓  $blockCount explicit block rule(s) present." Green }
    else { wh "  ⚠  No explicit block rules found." Yellow; $findings++ }

    if ($findings -eq 0) { wh "  ✓  No critical issues detected." Green }
    Write-Host ""
    wh "  Run 'killport openports' to cross-reference currently exposed ports." DarkGray
    Write-Host ""
}

# ── dns ──────────────────────────────────────────────────────────────────────

function Invoke-DnsRecon($domain) {
    if (-not $domain) { Write-Host ""; wh "  Usage: killport dns <domain>" Yellow; Write-Host ""; return }
    Write-Host ""
    wh "  killport dns" Cyan -nl; wh "  $domain" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""

    function Show-Recs($label, $records) {
        wh ("  {0,-8}" -f $label) -nl
        if (-not $records -or $records.Count -eq 0) { wh "  (none)" DarkGray; return }
        $first = $true
        foreach ($r in $records) {
            $val = if ($r.PSObject.Properties["IPAddress"]) { $r.IPAddress }
                   elseif ($r.PSObject.Properties["NameExchange"]) { "$($r.Preference) $($r.NameExchange)" }
                   elseif ($r.PSObject.Properties["NameHost"]) { $r.NameHost }
                   elseif ($r.PSObject.Properties["Strings"]) { $r.Strings -join " " }
                   else { $r.ToString() }
            if ($first) { wh "  $val" DarkGray; $first = $false } else { wh "          $val" DarkGray }
        }
    }

    foreach ($type in @("A","AAAA","MX","NS","TXT")) {
        try { $recs = @(Resolve-DnsName -Name $domain -Type $type -ErrorAction Stop 2>$null | Where-Object { $_.Type -eq $type }) } catch { $recs = @() }
        Show-Recs $type $recs
    }
    Write-Host ""

    # Reverse DNS for A records
    try {
        $aRecs = Resolve-DnsName -Name $domain -Type A -ErrorAction SilentlyContinue 2>$null
        if ($aRecs) {
            wh "  REVERSE " DarkGray
            foreach ($r in $aRecs | Where-Object { $_.IPAddress }) {
                $rev = try { (Resolve-DnsName -Name $r.IPAddress -ErrorAction SilentlyContinue).NameHost } catch { "(no PTR)" }
                wh "    $($r.IPAddress)  ->  $rev" DarkGray
            }
            Write-Host ""
        }
    } catch {}

    # Zone transfer attempt
    wh "  AXFR    " DarkGray
    try {
        $nsRecs = Resolve-DnsName -Name $domain -Type NS -ErrorAction SilentlyContinue 2>$null
        $axfrOk = $false
        foreach ($ns in $nsRecs | Where-Object { $_.NameHost }) {
            $nsHost = $ns.NameHost.TrimEnd(".")
            try {
                $result = & nslookup -type=AXFR $domain $nsHost 2>&1 | Out-String
                if ($result -notmatch "refused|failed|error|SERVFAIL" -and $result -match "\bIN\b") {
                    wh "    ⚠  Zone transfer ALLOWED from $nsHost — misconfiguration!" Red; $axfrOk = $true
                }
            } catch {}
        }
        if (-not $axfrOk) { wh "    ✓  Zone transfers blocked." Green }
    } catch { wh "    (could not test zone transfer)" DarkGray }
    Write-Host ""
}

# ── forward ──────────────────────────────────────────────────────────────────

function Forward-Port($localPort, $target) {
    if (-not $localPort -or -not $target) {
        Write-Host ""
        wh "  Usage: killport forward <local-port> <host:port>" Yellow
        wh "  Example: killport forward 8080 192.168.1.10:80" DarkGray
        Write-Host ""; return
    }
    if ($target -notmatch '^(.+):(\d+)$') { wh "  Target must be host:port" Yellow; return }
    $tHost = $Matches[1]; $tPort = $Matches[2]
    Write-Host ""
    wh "  killport forward" Cyan -nl; wh "  localhost:$localPort  ->  $target" DarkGray; Write-Host ""
    Write-Rule; Write-Host ""

    $ncat = Get-CmdPath ncat
    if ($ncat) {
        wh "  ✓  ncat — forwarding port $localPort to $target" Green
        wh "  Press Ctrl+C to stop." DarkGray; Write-Host ""
        try {
            while ($true) {
                & $ncat -l $localPort -c "ncat $tHost $tPort" 2>$null
            }
        } catch { wh "  Forward stopped." DarkGray }
    } else {
        wh "  Using .NET socket forwarder (single connection at a time)" DarkGray
        wh "  Install ncat for full multi-connection support: https://nmap.org" DarkGray
        wh "  Press Ctrl+C to stop." DarkGray; Write-Host ""
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, [int]$localPort)
            $listener.Start()
            wh "  Listening on port $localPort..." Green; Write-Host ""
            while ($true) {
                $client = $listener.AcceptTcpClient()
                $remote = [System.Net.Sockets.TcpClient]::new($tHost, [int]$tPort)
                $cs = $client.GetStream(); $rs = $remote.GetStream()
                $t1 = [System.Threading.Tasks.Task]::Run([System.Action]{ try { $cs.CopyTo($rs) } catch {} })
                $t2 = [System.Threading.Tasks.Task]::Run([System.Action]{ try { $rs.CopyTo($cs) } catch {} })
                [System.Threading.Tasks.Task]::WhenAny($t1,$t2) | Out-Null
                $client.Dispose(); $remote.Dispose()
            }
        } catch { wh "  Forward stopped." DarkGray }
        finally { if ($listener) { $listener.Stop() }; Write-Host "" }
    }
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
    Write-Host "  killport openports <ip>    probe an IP from this machine to check open ports"
    Write-Host "  killport closedports       show all listening ports with no external access"
    Write-Host "  killport status <port>     show if a port is open or closed"
    Write-Host "  killport ip                show IP addresses and network info"
    Write-Host "  killport scan <ip>         scan ports on a remote host (no AI)"
    Write-Host "  killport scan <ip> all     scan all 65535 ports on a remote host"
    Write-Host "  killport watch <port>      monitor live connections to a local port"
    Write-Host "  killport cert <host:port>  inspect TLS certificate (expiry, SANs, cipher)"
    Write-Host "  killport sniff <port>      capture and display traffic on a port"
    Write-Host "  killport sniff <ip:port>   capture traffic to/from a specific host:port"
    Write-Host "  killport vuln <ip:port>    detect service version + query CVE database"
    Write-Host "  killport fix <ip:port>     detect vulns and generate/apply a fix  (requires Ollama)"
    Write-Host "  killport audit             review firewall rules with plain-English findings"
    Write-Host "  killport dns <domain>      DNS recon: A/MX/TXT/NS/AXFR zone transfer test"
    Write-Host "  killport forward <p> <h:p> forward a local port to a remote host:port"
    Write-Host "  killport stress <ip:port>  authorized connection flood / stress test"
    Write-Host "  killport update            update to the latest version"
    Write-Host "  killport uninstall         remove killport and all firewall rules"
    Write-Host ""
    wh "  killport attack <ip>              AI pentest (common ports)  (requires Ollama)" DarkGray
    wh "  killport attack allports <ip>     AI pentest (all 65535 ports)  (requires Ollama)" DarkGray
    wh "  killport config            configure Ollama host and model" DarkGray
    wh "  killport attack log               view last attack log" DarkGray
    Write-Host ""
    exit 0
}

switch ($Command.ToLower()) {
    "update"      { Update-Killport }
    "uninstall"   { Uninstall-Killport }
    "list"        { List-Ports }
    "openports"   { Open-Ports $Port }
    "closedports" { Closed-Ports }
    "ip"          { Show-IP }
    "config"      { Invoke-AttackConfig }
    "attack"      { Invoke-AttackDispatch $Port $Extra }
    "stress"      { Invoke-StressDispatch $Port }
    "scan"        { Invoke-Scan $Port $Extra }
    "watch"       { Watch-PortConnections $Port }
    "cert"        { Check-Cert $Port }
    "sniff"       { Sniff-Port $Port }
    "vuln"        { Check-Vuln $Port }
    "fix"         { Invoke-FixDispatch $Port }
    "audit"       { Audit-Firewall }
    "dns"         { Invoke-DnsRecon $Port }
    "forward"     { Forward-Port $Port $Extra }
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
