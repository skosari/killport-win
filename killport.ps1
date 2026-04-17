param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Port
)

if (-not $Port) {
    Write-Host "Usage: killport <port>"
    Write-Host "       killport list"
    Write-Host ""
    Write-Host "Listening ports:"
    Write-Host ""
    $connections = netstat -ano | Select-String "LISTENING"
    $seen = @{}
    foreach ($line in $connections) {
        $parts = ($line -split '\s+') | Where-Object { $_ -ne '' }
        $localAddr = $parts[1]
        $pid = $parts[-1]
        if ($seen[$pid + $localAddr]) { continue }
        $seen[$pid + $localAddr] = $true
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, $proc.Name, $pid)
        } catch {
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, "(unknown)", $pid)
        }
    }
    exit 0
}

# --- list all listening ports ---
if ($Port -eq "list") {
    Write-Host "Listening ports:"
    Write-Host ""
    $connections = netstat -ano | Select-String "LISTENING"
    $seen = @{}
    foreach ($line in $connections) {
        $parts = ($line -split '\s+') | Where-Object { $_ -ne '' }
        $localAddr = $parts[1]
        $pid = $parts[-1]
        if ($seen[$pid + $localAddr]) { continue }
        $seen[$pid + $localAddr] = $true
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, $proc.Name, $pid)
        } catch {
            Write-Host ("  {0,-25} {1,-10} {2}" -f $localAddr, "(unknown)", $pid)
        }
    }
    exit 0
}

if ($Port -notmatch '^\d+$' -or [int]$Port -lt 1 -or [int]$Port -gt 65535) {
    Write-Error "Error: '$Port' is not a valid port number (1-65535)"
    exit 1
}

$connections = netstat -ano | Select-String ":$Port\s"

if (-not $connections) {
    Write-Host "Nothing running on port $Port"
    exit 0
}

$pids = $connections | ForEach-Object {
    ($_ -split '\s+')[-1]
} | Sort-Object -Unique

if (-not $pids) {
    Write-Host "Nothing running on port $Port"
    exit 0
}

Write-Host "Port $Port is in use:"
Write-Host ""

foreach ($pid in $pids) {
    try {
        $proc = Get-Process -Id $pid -ErrorAction Stop
        Write-Host "  PID:     $($proc.Id)"
        Write-Host "  Name:    $($proc.Name)"
        Write-Host "  Path:    $($proc.Path)"
        Write-Host ""
    } catch {
        Write-Host "  PID:     $pid (process info unavailable)"
        Write-Host ""
    }
}

foreach ($pid in $pids) {
    try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
    } catch {
        Write-Warning "Could not kill PID $pid`: $_"
    }
}

Write-Host "Killed."
