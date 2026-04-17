$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Please run as Administrator (right-click PowerShell -> Run as administrator)."
    exit 1
}

Write-Host "Uninstalling killport..."

# Remove all firewall rules created by killport open
$rules = Get-NetFirewallRule -DisplayName "killport-*" -ErrorAction SilentlyContinue
if ($rules) {
    $rules | Remove-NetFirewallRule
    Write-Host "  Removed $($rules.Count) firewall rule(s)"
}

# Remove bat wrapper from System32
$bat = "$env:SystemRoot\System32\killport.bat"
if (Test-Path $bat) { Remove-Item $bat -Force; Write-Host "  Removed $bat" }

# Remove implementation from ProgramData
$impl = "$env:ProgramData\killport"
if (Test-Path $impl) { Remove-Item $impl -Recurse -Force; Write-Host "  Removed $impl" }

# Remove any old WindowsApps installs
@(
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.ps1",
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\killport.bat"
) | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Force; Write-Host "  Removed $_" }

Write-Host "killport uninstalled."
