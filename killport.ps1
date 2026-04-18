param(
    [Parameter(Mandatory=$false, Position=0)] [string]$Command,
    [Parameter(Mandatory=$false, Position=1)] [string]$Port,
    [Parameter(Mandatory=$false, Position=2)] [string]$Extra
)

$VERSION = "1.8.0"
$REPO    = "skosari/killport-win"
$RAW     = "https://raw.githubusercontent.com/$REPO/main"

# ── helpers ─────────────────────────────────────────────────────────────────

function wh($msg, $fg, [switch]$nl = $true) {
    if ($fg) { Write-Host $msg -ForegroundColor $fg -NoNewline:(!$nl) }
    else     { Write-Host $msg -NoNewline:(!$nl) }
}

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
        wh "  Firewall:  " -nl:$false; wh "CLOSED" DarkGray -nl:$false; Write-Host "  (no killport rule - external access blocked)"
    }
    $conn = netstat -ano | Select-String ":$p\s" | Select-String /i "LISTENING"
    if ($conn) {
        $pid = (($conn | Select-Object -First 1) -split '\s+')[-1]
        try   { $name = (Get-Process -Id $pid -ErrorAction Stop).Name }
        catch { $name = "?" }
        wh "  Listening: " -nl:$false; wh "YES" Green -nl:$false; Write-Host "  (PID: $pid - $name)"
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
        catch { wh "Could not kill PID $pid - try running as Administrator." Yellow; $failed = $true }
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
        [System.IO.File]::WriteAllText($batPath, $content, [System.Text.Encoding]::UTF8)
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
        Write-Host "  Run: " -NoNewline; wh "killport attack config" White
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
        Write-Host "  Start Ollama and re-run, or update: " -NoNewline; wh "killport attack config" White
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
            Write-Host "  killport attack <ip>              AI pentest (common ports)"
            Write-Host "  killport attack allports <ip>     AI pentest (all 65535 ports)"
            Write-Host "  killport attack config            configure Ollama host and model"
            Write-Host "  killport attack log               view last attack log"
            Write-Host ""
        }
        default    { Start-AttackRun $sub }
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
    Write-Host "  killport closedports       show all listening ports with no external access"
    Write-Host "  killport status <port>     show if a port is open or closed"
    Write-Host "  killport ip                show IP addresses and network info"
    Write-Host "  killport update            update to the latest version"
    Write-Host "  killport uninstall         remove killport and all firewall rules"
    Write-Host ""
    wh "  killport attack <ip>              AI pentest (common ports)" DarkGray
    wh "  killport attack allports <ip>     AI pentest (all 65535 ports)" DarkGray
    wh "  killport attack config            configure Ollama host and model" DarkGray
    wh "  killport attack log               view last attack log" DarkGray
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
    "attack"      { Invoke-AttackDispatch $Port $Extra }
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
