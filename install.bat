@echo off
setlocal

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator ^(right-click CMD, "Run as administrator"^).
    exit /b 1
)

echo Installing killport...

if not exist "%ProgramData%\killport" mkdir "%ProgramData%\killport"

curl -fsSL "https://raw.githubusercontent.com/skosari/killport-win/main/killport.ps1" -o "%ProgramData%\killport\killport.ps1"
if %errorlevel% neq 0 ( echo Download failed. Check your internet connection. & exit /b 1 )

curl -fsSL "https://raw.githubusercontent.com/skosari/killport-win/main/killport.bat" -o "%SystemRoot%\System32\killport.bat"
if %errorlevel% neq 0 ( echo Download failed. & exit /b 1 )

echo killport installed. Type 'killport' to get started.
endlocal
