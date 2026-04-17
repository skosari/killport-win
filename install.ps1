$REPO = "skosari/killport-win"
$RAW_URL = "https://raw.githubusercontent.com/$REPO/main/killport.ps1"
$INSTALL_DIR = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"
$DEST = "$INSTALL_DIR\killport.ps1"

Write-Host "Installing killport..."

try {
    Invoke-WebRequest -Uri $RAW_URL -OutFile $DEST -UseBasicParsing
} catch {
    Write-Error "Failed to download killport: $_"
    exit 1
}

# Create a wrapper .cmd so you can just type `killport` in any terminal
$CMD_DEST = "$INSTALL_DIR\killport.cmd"
Set-Content -Path $CMD_DEST -Value "@powershell -ExecutionPolicy Bypass -File `"$DEST`" %*"

Write-Host "killport installed."
Write-Host "Try: killport 8080"
