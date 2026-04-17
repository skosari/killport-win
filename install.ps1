$REPO = "skosari/killport-win"
$RAW = "https://raw.githubusercontent.com/$REPO/main"
$INSTALL_DIR = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"

Write-Host "Installing killport..."

# PowerShell version
try {
    Invoke-WebRequest -Uri "$RAW/killport.ps1" -OutFile "$INSTALL_DIR\killport.ps1" -UseBasicParsing
} catch {
    Write-Error "Failed to download killport.ps1: $_"
    exit 1
}

# CMD/batch version (works in Command Prompt without PowerShell)
try {
    Invoke-WebRequest -Uri "$RAW/killport.bat" -OutFile "$INSTALL_DIR\killport.bat" -UseBasicParsing
} catch {
    Write-Error "Failed to download killport.bat: $_"
    exit 1
}

Write-Host "killport installed."
Write-Host ""
Write-Host "  PowerShell:       killport 8080"
Write-Host "  Command Prompt:   killport 8080"
