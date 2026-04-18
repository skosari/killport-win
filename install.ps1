$REPO       = "skosari/killport-win"
$RAW        = "https://raw.githubusercontent.com/$REPO/main"
$SYSTEM_DIR = "$env:SystemRoot\System32"
$IMPL_DIR   = "$env:ProgramData\killport"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run this installer as Administrator (right-click PowerShell -> Run as administrator)."
    exit 1
}

Write-Host "Installing killport..."

# PS1 implementation goes to ProgramData (not in PATH, so execution policy never blocks it)
New-Item -ItemType Directory -Force -Path $IMPL_DIR | Out-Null
try {
    $content = (Invoke-WebRequest -Uri "$RAW/killport.ps1" -UseBasicParsing).Content
    [System.IO.File]::WriteAllText("$IMPL_DIR\killport.ps1", $content, (New-Object System.Text.UTF8Encoding $True))
} catch {
    Write-Error "Failed to download killport.ps1: $_"; exit 1
}

# BAT wrapper goes to System32 (always in PATH, calls PS1 with -ExecutionPolicy Bypass)
try {
    $content = (Invoke-WebRequest -Uri "$RAW/killport.bat" -UseBasicParsing).Content
    $content = $content -replace "`r`n", "`n" -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText("$SYSTEM_DIR\killport.bat", $content, [System.Text.Encoding]::UTF8)
} catch {
    Write-Error "Failed to download killport.bat: $_"; exit 1
}

# Clean up old installs that may cause conflicts
@(
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.ps1",
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.bat"
) | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Force }

Write-Host "killport installed successfully."
Write-Host ""
Write-Host "  PowerShell:       killport 8080"
Write-Host "  Command Prompt:   killport 8080"
