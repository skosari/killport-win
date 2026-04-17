@echo off
setlocal enabledelayedexpansion

set VERSION=1.6.0
set REPO=skosari/killport-win
set RAW=https://raw.githubusercontent.com/%REPO%/main

if "%~1"=="" goto no_args
if /i "%~1"=="list" goto list_ports
if /i "%~1"=="update" goto do_update
if /i "%~1"=="ip" goto show_ip
if /i "%~1"=="open" goto open_port
if /i "%~1"=="close" goto close_port
if /i "%~1"=="status" goto status_port
if /i "%~1"=="openports" goto open_ports
if /i "%~1"=="closedports" goto closed_ports
goto kill_port

:: -------------------------------------------------------
:no_args
chcp 65001 >nul 2>&1
color 0B
echo ██╗  ██╗██╗██╗     ██╗     ██████╗  ██████╗ ██████╗ ████████╗
echo ██║ ██╔╝██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
echo █████╔╝ ██║██║     ██║     ██████╔╝██║   ██║██████╔╝   ██║
echo ██╔═██╗ ██║██║     ██║     ██╔═══╝ ██║   ██║██╔══██╗   ██║
echo ██║  ██╗██║███████╗███████╗██║     ╚██████╔╝██║  ██╗   ██║
echo ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝
echo.
echo   v%VERSION%
echo.
echo   killport                   show this help and list listening ports
echo   killport ^<port^>            kill whatever is running on that port
echo   killport list              list all listening ports
echo   killport open ^<port^>       open a port to external connections
echo   killport close ^<port^>      close a port from external connections
echo   killport openports         show all ports open to external access
echo   killport closedports       show all listening ports with no external access
echo   killport status ^<port^>     show if a port is open or closed
echo   killport ip                show IP addresses, DNS, and network info
echo   killport update            update to the latest version
echo.
call :check_update
goto end

:: -------------------------------------------------------
:check_update
curl -fsSL --max-time 2 "%RAW%/VERSION" -o "%TEMP%\killport_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_ver.txt" exit /b
set /p REMOTE_VER=<"%TEMP%\killport_ver.txt"
del "%TEMP%\killport_ver.txt" >nul 2>&1
set REMOTE_VER=%REMOTE_VER: =%
if not "%REMOTE_VER%"=="%VERSION%" (
  echo   Update available: %VERSION% -^> %REMOTE_VER%  ^(run: killport update^)
  echo.
)
exit /b

:: -------------------------------------------------------
:list_ports
echo Listening ports:
echo.
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /i "LISTENING"') do (
  set PROCNAME=
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set PROCNAME=%%~p
  if "!PROCNAME!"=="" set PROCNAME=(unknown)
  echo   %%b	!PROCNAME!	%%e
)
echo.
goto end

:: -------------------------------------------------------
:do_update
echo Checking for updates...
curl -fsSL --max-time 5 "%RAW%/VERSION" -o "%TEMP%\killport_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_ver.txt" ( echo Could not reach GitHub. & goto end )
set /p REMOTE_VER=<"%TEMP%\killport_ver.txt"
del "%TEMP%\killport_ver.txt" >nul 2>&1
set REMOTE_VER=%REMOTE_VER: =%
if "%REMOTE_VER%"=="%VERSION%" ( echo Already up to date ^(v%VERSION%^) & goto end )
echo Updating %VERSION% -^> %REMOTE_VER%...
curl -fsSL "%RAW%/killport.bat" -o "%~f0.tmp" >nul 2>&1
if errorlevel 1 ( echo Download failed. Try running as Administrator. & goto end )
move /y "%~f0.tmp" "%~f0" >nul 2>&1
echo Updated to v%REMOTE_VER%. Run killport to confirm.
goto end

:: -------------------------------------------------------
:show_ip
echo Network Interfaces
echo ────────────────────────────────────
ipconfig /all | findstr /i "adapter description physical ipv4 ipv6 default dns"
echo.
goto end

:: -------------------------------------------------------
:open_port
if "%~2"=="" ( echo Usage: killport open ^<port^> & goto end )
set PORT=%~2
echo Opening port %PORT% to external connections...
netsh advfirewall firewall add rule name="killport-%PORT%-tcp" protocol=TCP dir=in localport=%PORT% action=allow >nul
netsh advfirewall firewall add rule name="killport-%PORT%-udp" protocol=UDP dir=in localport=%PORT% action=allow >nul
echo Port %PORT% is now open (TCP + UDP).
goto end

:: -------------------------------------------------------
:close_port
if "%~2"=="" ( echo Usage: killport close ^<port^> & goto end )
set PORT=%~2
echo Closing port %PORT% from external connections...
netsh advfirewall firewall delete rule name="killport-%PORT%-tcp" >nul 2>&1
netsh advfirewall firewall delete rule name="killport-%PORT%-udp" >nul 2>&1
echo Port %PORT% is now closed.
goto end

:: -------------------------------------------------------
:status_port
if "%~2"=="" ( echo Usage: killport status ^<port^> & goto end )
set PORT=%~2
echo Port %PORT% status:
echo.
set FW_OPEN=0
netsh advfirewall firewall show rule name="killport-%PORT%-tcp" >nul 2>&1 && set FW_OPEN=1
if "%FW_OPEN%"=="1" (
  echo   Firewall:  OPEN  ^(killport rule allows external access^)
) else (
  echo   Firewall:  CLOSED  ^(no killport rule — external access blocked^)
)
set LISTENING=0
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr /i "LISTENING"') do (
  set LISTENING=1
  set LPID=%%a
)
if "%LISTENING%"=="1" (
  set LNAME=
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %LPID%" /fo csv /nh 2^>nul') do set LNAME=%%~p
  echo   Listening: YES  ^(PID: %LPID% — !LNAME!^)
) else (
  echo   Listening: NO  ^(nothing is running on this port^)
)
goto end

:: -------------------------------------------------------
:open_ports
echo Open ports (allowed external access via killport):
echo.
set FOUND_OPEN=0
for /f "tokens=5" %%a in ('netsh advfirewall firewall show rule name^=all ^| findstr /i "killport-"') do (
  set FOUND_OPEN=1
)
for /f "tokens=2 delims=-" %%a in ('netsh advfirewall firewall show rule name^=all ^| findstr /i "killport-" ^| findstr /v "udp"') do (
  set PORT=%%a
  set PROCNAME=
  for /f "tokens=5" %%b in ('netstat -ano ^| findstr ":!PORT! " ^| findstr /i "LISTENING"') do (
    for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%b" /fo csv /nh 2^>nul') do set PROCNAME=%%~p
    if "!PROCNAME!"=="" set PROCNAME=unknown
    echo   !PORT!    listening  (!PROCNAME!)
  )
)
if "%FOUND_OPEN%"=="0" echo   None — no ports have been opened with killport.
echo.
goto end

:: -------------------------------------------------------
:closed_ports
echo Closed ports (listening locally, no external access):
echo.
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /i "LISTENING"') do (
  set ADDR=%%b
  set PID=%%e
  for /f "delims=: tokens=2" %%p in ("%%b") do set PORT=%%p
  netsh advfirewall firewall show rule name="killport-!PORT!-tcp" >nul 2>&1
  if errorlevel 1 (
    set PROCNAME=
    for /f "tokens=1 delims=," %%q in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set PROCNAME=%%~q
    if "!PROCNAME!"=="" set PROCNAME=unknown
    echo   !PORT!    closed  (!PROCNAME!)
  )
)
echo.
goto end

:: -------------------------------------------------------
:kill_port
set PORT=%~1
set /a PORT_CHECK=%PORT% 2>nul
if %PORT_CHECK% LSS 1 ( echo Error: '%PORT%' is not a valid port number ^(1-65535^) & goto end )
if %PORT_CHECK% GTR 65535 ( echo Error: '%PORT%' is not a valid port number ^(1-65535^) & goto end )

set FOUND=0
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr /i "LISTENING"') do (
  set FOUND=1
  set PROCNAME=
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set PROCNAME=%%~p
  if "!PROCNAME!"=="" set PROCNAME=(unknown)
  echo Port %PORT% is in use:
  echo.
  echo   PID:   %%e
  echo   Name:  !PROCNAME!
  echo   Addr:  %%b
  echo.
  taskkill /PID %%e /F >nul 2>&1
  if errorlevel 1 ( echo Could not kill PID %%e - try running as Administrator. ) else ( echo Killed. )
)
if "%FOUND%"=="0" echo Nothing running on port %PORT%

:: -------------------------------------------------------
:end
endlocal
