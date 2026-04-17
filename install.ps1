$REPO = "skosari/killport-win"
$RAW = "https://raw.githubusercontent.com/$REPO/main"
$INSTALL_DIR = "$env:SystemRoot\System32"

# Must run as Administrator so we can write to System32
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run this installer as Administrator (right-click PowerShell -> Run as administrator)."
    exit 1
}

Write-Host "Installing killport to $INSTALL_DIR ..."

try {
    $content = (Invoke-WebRequest -Uri "$RAW/killport.bat" -UseBasicParsing).Content
    # Ensure CRLF line endings — CMD batch parser breaks on LF-only files
    $content = $content -replace "`r`n", "`n" -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText("$INSTALL_DIR\killport.bat", $content, [System.Text.Encoding]::UTF8)
} catch {
    Write-Error "Failed to download killport.bat: $_"
    exit 1
}

Write-Host "killport installed successfully."
Write-Host ""
Write-Host "  PowerShell:       killport 8080"
Write-Host "  Command Prompt:   killport 8080"
