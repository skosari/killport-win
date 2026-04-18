param(
    [Parameter(Mandatory=$false, Position=0)] [string]$Command,
    [Parameter(Mandatory=$false, Position=1)] [string]$Port,
    [Parameter(Mandatory=$false, Position=2)] [string]$Extra
)

$VERSION = "1.7.2"
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
import sys, json, subprocess, re, datetime, urllib.request

target   = sys.argv[1]
host     = sys.argv[2]
model    = sys.argv[3]
log_path = sys.argv[4]
nmap_out = sys.stdin.read()

MAX_ITERS = 12
TOOLS = {
    "nmap_scan":   "nmap -sV --open -p {ports} {target}",
    "http_probe":  "curl -sk --max-time 5 http://{target}:{port}/",
    "https_probe": "curl -sk --max-time 5 https://{target}:{port}/",
    "banner_grab": "nmap -sV -p {port} {target}",
    "run_script":  "nmap --script={script} -p {port} {target}",
}

def ollama_chat(messages):
    body = json.dumps({"model":model,"messages":messages,"stream":False}).encode()
    req  = urllib.request.Request(f"{host}/api/chat", data=body,
                                   headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            content = json.loads(r.read())["message"]["content"]
            content = re.sub(r'<think>.*?</think>','',content,flags=re.DOTALL)
            content = re.sub(r'^.*?</think>\s*','',content,flags=re.DOTALL)
            content = re.sub(r'<think>.*$','',content,flags=re.DOTALL)
            return content.strip()
    except Exception as e:
        return f"ERROR: {e}"

def run_tool(name, params):
    tpl = TOOLS.get(name)
    if not tpl: return f"Unknown tool: {name}"
    try:
        cmd = tpl.format(target=target, **params)
        r   = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        return (r.stdout + r.stderr).strip() or "(no output)"
    except Exception as e:
        return f"Error: {e}"

def log(text):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] {text}\n")

SYSTEM = f"""You are an expert penetration tester investigating: {target}
Use a ReAct loop: Thought -> Action -> Observation -> repeat -> Final Answer.

Available tools (JSON):
{json.dumps(TOOLS, indent=2)}

Format each action as:
Action: {{"tool": "tool_name", "params": {{...}}}}

When done:
Final Answer: <full markdown pentest report>"""

messages = [
    {"role":"system","content":SYSTEM},
    {"role":"user",  "content":f"Initial nmap scan:\n\n{nmap_out}\n\nBegin your investigation."}
]

log(f"=== Attack started: {target} ===  model={model}")

for _ in range(MAX_ITERS):
    reply = ollama_chat(messages)
    if not reply: print("  [AI] No response from Ollama."); break
    print(f"\n  [AI] {reply}\n"); log(f"AI: {reply}")

    if "Final Answer:" in reply:
        report = reply.split("Final Answer:",1)[1].strip()
        log(f"REPORT:\n{report}")
        print("\n" + "="*60 + "\n  PENTEST REPORT\n" + "="*60)
        print(report)
        print("="*60 + "\n")
        break

    m = re.search(r'Action:\s*(\{.*?\})', reply, re.DOTALL)
    if m:
        try:
            act  = json.loads(m.group(1))
            name = act.get("tool",""); params = act.get("params",{})
            print(f"  [TOOL] {name}({params})"); log(f"TOOL: {name}({params})")
            obs  = run_tool(name, params)
            print(f"  [OBS]  {obs[:500]}"); log(f"OBS: {obs[:500]}")
            messages += [{"role":"assistant","content":reply},
                         {"role":"user","content":f"Observation: {obs}"}]
        except json.JSONDecodeError:
            messages += [{"role":"assistant","content":reply},
                         {"role":"user","content":"Continue your investigation."}]
    else:
        messages += [{"role":"assistant","content":reply},
                     {"role":"user","content":"Continue your investigation."}]

log(f"=== Attack ended: {target} ===")
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
