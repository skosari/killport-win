@echo off
setlocal enabledelayedexpansion

set VERSION=1.6.6
set REPO=skosari/killport-win
set RAW=https://raw.githubusercontent.com/%REPO%/main

chcp 65001 >nul 2>&1
for /f %%a in ('powershell -NoProfile -c "[char]27"') do set "ESC=%%a"
set "CY=%ESC%[0;36m"
set "GR=%ESC%[0;32m"
set "YL=%ESC%[0;33m"
set "BD=%ESC%[1m"
set "DM=%ESC%[2m"
set "RS=%ESC%[0m"
set "BC=%ESC%[1;36m"
set "BG=%ESC%[1;32m"

if "%~1"=="" goto no_args
if /i "%~1"=="list"        goto list_ports
if /i "%~1"=="update"      goto do_update
if /i "%~1"=="ip"          goto show_ip
if /i "%~1"=="open"        goto open_port
if /i "%~1"=="close"       goto close_port
if /i "%~1"=="status"      goto status_port
if /i "%~1"=="openports"   goto open_ports
if /i "%~1"=="closedports" goto closed_ports
goto kill_port

:: -------------------------------------------------------
:no_args
echo !CY!██╗  ██╗██╗██╗     ██╗     ██████╗  ██████╗ ██████╗ ████████╗!RS!
echo !CY!██║ ██╔╝██║██║     ██║     ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝!RS!
echo !CY!█████╔╝ ██║██║     ██║     ██████╔╝██║   ██║██████╔╝   ██║   !RS!
echo !CY!██╔═██╗ ██║██║     ██║     ██╔═══╝ ██║   ██║██╔══██╗   ██║   !RS!
echo !CY!██║  ██╗██║███████╗███████╗██║     ╚██████╔╝██║  ██╗   ██║   !RS!
echo !CY!╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   !RS!
echo.
echo   !DM!https://github.com/skosari/killport-win!RS!
echo.
call :check_update
echo.
echo   !BD!killport!RS!                   show this help
echo   !BD!killport ^<port^>!RS!            kill whatever is running on that port
echo   !BD!killport list!RS!              list all listening ports
echo   !BD!killport open ^<port^>!RS!       open a port to external connections
echo   !BD!killport close ^<port^>!RS!      close a port from external connections
echo   !BD!killport openports!RS!         show all ports open to external access
echo   !BD!killport closedports!RS!       show all listening ports with no external access
echo   !BD!killport status ^<port^>!RS!     show if a port is open or closed
echo   !BD!killport ip!RS!                show IP addresses and network info
echo   !BD!killport update!RS!            update to the latest version
echo.
goto end

:: -------------------------------------------------------
:check_update
curl -fsSL --max-time 2 "%RAW%/VERSION" -o "%TEMP%\killport_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_ver.txt" (
  echo   !DM!v%VERSION%!RS!
  exit /b
)
set /p REMOTE_VER=<"%TEMP%\killport_ver.txt"
del "%TEMP%\killport_ver.txt" >nul 2>&1
set "REMOTE_VER=%REMOTE_VER: =%"
if not "%REMOTE_VER%"=="%VERSION%" (
  echo   !YL!v%VERSION%  →  v%REMOTE_VER% available  (run: killport update)!RS!
) else (
  echo   !DM!v%VERSION%!RS!
)
exit /b

:: -------------------------------------------------------
:list_ports
echo.
echo   !BD!!CY!Listening Ports!RS!
echo   !CY!────────────────────────────────────────────!RS!
echo.
set "SEEN="
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /i "LISTENING"') do (
  set "ADDR=%%b"
  set "PID=%%e"
  set "KEY=%%b__%%e"
  echo !SEEN! | findstr /c:"[!KEY!]" >nul 2>&1
  if errorlevel 1 (
    set "SEEN=!SEEN![!KEY!]"
    set "PROCNAME="
    for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set "PROCNAME=%%~p"
    if "!PROCNAME!"=="" set "PROCNAME=(unknown)"
    set "PAD=!ADDR!                              "
    set "PAD=!PAD:~0,28!"
    echo   !GR!●!RS!  !PAD!!DM!!PROCNAME!!RS!
  )
)
echo.
goto end

:: -------------------------------------------------------
:do_update
echo Checking for updates...
curl -fsSL --max-time 5 "%RAW%/VERSION" -o "%TEMP%\killport_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_ver.txt" ( echo !YL!Could not reach GitHub.!RS! & goto end )
set /p REMOTE_VER=<"%TEMP%\killport_ver.txt"
del "%TEMP%\killport_ver.txt" >nul 2>&1
set "REMOTE_VER=%REMOTE_VER: =%"
if "%REMOTE_VER%"=="%VERSION%" ( echo !GR!Already up to date (v%VERSION%)!RS! & goto end )
echo Updating %VERSION% !YL!→!RS! %REMOTE_VER%...
curl -fsSL "%RAW%/killport.bat" -o "%~f0.tmp" >nul 2>&1
if errorlevel 1 ( echo !YL!Download failed. Try running as Administrator.!RS! & goto end )
move /y "%~f0.tmp" "%~f0" >nul 2>&1
echo !GR!Updated to v%REMOTE_VER%. Run killport to confirm.!RS!
goto end

:: -------------------------------------------------------
:show_ip
echo.
echo   !BD!!CY!Network Addresses!RS!
echo   !CY!────────────────────────────────────────────!RS!
echo.
set "CUR_ADAPTER="
set "PRIMARY_ADAPTER="
set "PRIMARY_IP="
set "FOUND_PRIMARY=0"
for /f "tokens=*" %%L in ('ipconfig') do (
  set "LINE=%%L"
  echo !LINE! | findstr /i " adapter " >nul 2>&1
  if not errorlevel 1 set "CUR_ADAPTER=!LINE!"
  echo !LINE! | findstr /i "IPv4" >nul 2>&1
  if not errorlevel 1 (
    for /f "tokens=2 delims=:" %%I in ("!LINE!") do (
      set "RAW_IP=%%I"
      set "RAW_IP=!RAW_IP: =!"
      set "RAW_IP=!RAW_IP:(Preferred)=!"
      echo !RAW_IP! | findstr /b "127\." >nul 2>&1
      if errorlevel 1 (
        if "!FOUND_PRIMARY!"=="0" (
          set "FOUND_PRIMARY=1"
          set "PRIMARY_ADAPTER=!CUR_ADAPTER!"
          set "PRIMARY_IP=!RAW_IP!"
        ) else (
          echo   !DM!!CUR_ADAPTER!!RS!
          echo   !DM!──^> !RAW_IP!!RS!
          echo.
        )
      )
    )
  )
)
if not "!PRIMARY_IP!"=="" (
  echo   !BC!┌────────────────────────────────────────!RS!
  echo   !BC!│!RS!  !PRIMARY_ADAPTER!
  echo   !BC!│!RS!  !BD!IPv4:!RS!  !BG!!PRIMARY_IP!!RS!
  echo   !BC!└────────────────────────────────────────!RS!
  echo.
)
echo   !BD!Default Gateway!RS!
echo   !CY!────────────────────────────────────!RS!
for /f "tokens=*" %%G in ('ipconfig ^| findstr "Default Gateway"') do (
  set "GW_LINE=%%G"
  set "GW=!GW_LINE:*: =!"
  set "GW=!GW: =!"
  if not "!GW!"=="" if not "!GW!"=="." echo   !GW!
)
echo.
echo   !BD!DNS Servers!RS!
echo   !CY!────────────────────────────────────!RS!
for /f "tokens=*" %%D in ('ipconfig /all ^| findstr "DNS Servers"') do (
  set "DNS_LINE=%%D"
  set "DNS=!DNS_LINE:*: =!"
  set "DNS=!DNS: =!"
  if not "!DNS!"=="" if not "!DNS!"=="." echo   !DNS!
)
echo.
echo   !BD!Firewall-managed ports (killport)!RS!
echo   !CY!────────────────────────────────────!RS!
set "FOUND_RULES=0"
for /f "tokens=2 delims=-" %%P in ('netsh advfirewall firewall show rule name^=all 2^>nul ^| findstr /i "killport-" ^| findstr /v "udp"') do (
  set "FOUND_RULES=1"
  echo   %%P
)
if "!FOUND_RULES!"=="0" echo   !DM!None!RS!
echo.
goto end

:: -------------------------------------------------------
:open_port
if "%~2"=="" ( echo Usage: killport open ^<port^> & goto end )
set "PORT=%~2"
echo Opening port !BD!!PORT!!RS! to external connections...
netsh advfirewall firewall add rule name="killport-%PORT%-tcp" protocol=TCP dir=in localport=%PORT% action=allow >nul
netsh advfirewall firewall add rule name="killport-%PORT%-udp" protocol=UDP dir=in localport=%PORT% action=allow >nul
echo !GR!Port %PORT% is now open (TCP + UDP).!RS!
goto end

:: -------------------------------------------------------
:close_port
if "%~2"=="" ( echo Usage: killport close ^<port^> & goto end )
set "PORT=%~2"
echo Closing port !BD!!PORT!!RS! from external connections...
netsh advfirewall firewall delete rule name="killport-%PORT%-tcp" >nul 2>&1
netsh advfirewall firewall delete rule name="killport-%PORT%-udp" >nul 2>&1
echo !DM!Port %PORT% is now closed.!RS!
goto end

:: -------------------------------------------------------
:status_port
if "%~2"=="" ( echo Usage: killport status ^<port^> & goto end )
set "PORT=%~2"
echo.
echo   Port !BD!!PORT!!RS! status:
echo.
set "FW_OPEN=0"
netsh advfirewall firewall show rule name="killport-%PORT%-tcp" >nul 2>&1 && set "FW_OPEN=1"
if "!FW_OPEN!"=="1" (
  echo   Firewall:  !GR!OPEN!RS!  (killport rule allows external access)
) else (
  echo   Firewall:  !DM!CLOSED!RS!  (no killport rule — external access blocked)
)
set "LISTENING=0"
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr /i "LISTENING"') do (
  set "LISTENING=1"
  set "LPID=%%a"
)
if "!LISTENING!"=="1" (
  set "LNAME="
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq !LPID!" /fo csv /nh 2^>nul') do set "LNAME=%%~p"
  echo   Listening: !GR!YES!RS!  (PID: !LPID! — !LNAME!)
) else (
  echo   Listening: !DM!NO!RS!  (nothing is running on this port)
)
echo.
goto end

:: -------------------------------------------------------
:open_ports
echo.
echo   !BD!!CY!Firewall-Open Ports!RS!  !DM!(external access via killport)!RS!
echo   !CY!────────────────────────────────────────────!RS!
echo.
set "OPEN_COUNT=0"
set "LISTEN_COUNT=0"
for /f "tokens=2 delims=-" %%P in ('netsh advfirewall firewall show rule name^=all 2^>nul ^| findstr /i "killport-" ^| findstr /v "udp"') do (
  set "PORT=%%P"
  set /a OPEN_COUNT+=1
  set "PROC="
  for /f "tokens=5" %%b in ('netstat -ano ^| findstr ":!PORT! " ^| findstr /i "LISTENING"') do (
    for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%b" /fo csv /nh 2^>nul') do set "PROC=%%~p"
  )
  set "PPAD=!PORT!        "
  set "PPAD=!PPAD:~0,8!"
  if not "!PROC!"=="" (
    set /a LISTEN_COUNT+=1
    echo   !GR!●!RS!  !BD!!PPAD!!RS!  !GR!listening!RS!   !DM!!PROC!!RS!
  ) else (
    echo   !YL!○!RS!  !BD!!PPAD!!RS!  !DM!not listening!RS!
  )
)
if "!OPEN_COUNT!"=="0" (
  echo   !DM!No ports are currently open to external access.!RS!
  echo   !DM!Run: killport open ^<port^>!RS!
)
echo.
echo   !CY!────────────────────────────────────────────!RS!
echo   !DM!!OPEN_COUNT! port(s) open  ·  !LISTEN_COUNT! listening!RS!
echo.
goto end

:: -------------------------------------------------------
:closed_ports
echo.
echo   !BD!!CY!Locally-Listening Ports!RS!  !DM!(no external access)!RS!
echo   !CY!────────────────────────────────────────────!RS!
echo.
set "CLOSED_COUNT=0"
set "SEEN_CLOSED="
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /i "LISTENING"') do (
  set "ADDR=%%b"
  set "PID=%%e"
  for /f "delims=: tokens=2" %%p in ("%%b") do set "PORT=%%p"
  if not "!PORT!"=="" (
    echo !SEEN_CLOSED! | findstr /c:"[!PORT!]" >nul 2>&1
    if errorlevel 1 (
      netsh advfirewall firewall show rule name="killport-!PORT!-tcp" >nul 2>&1
      if errorlevel 1 (
        set "SEEN_CLOSED=!SEEN_CLOSED![!PORT!]"
        set "PROCNAME="
        for /f "tokens=1 delims=," %%q in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set "PROCNAME=%%~q"
        if "!PROCNAME!"=="" set "PROCNAME=(unknown)"
        set /a CLOSED_COUNT+=1
        set "PPAD=!PORT!        "
        set "PPAD=!PPAD:~0,8!"
        echo   !YL!◆!RS!  !BD!!PPAD!!RS!  !DM!local only   !PROCNAME!!RS!
      )
    )
  )
)
echo.
echo   !CY!────────────────────────────────────────────!RS!
echo   !DM!!CLOSED_COUNT! port(s) listening locally  ·  no external access!RS!
echo.
goto end

:: -------------------------------------------------------
:kill_port
set "PORT=%~1"
set /a PORT_CHECK=%PORT% 2>nul
if %PORT_CHECK% LSS 1 ( echo !YL!Error: '%PORT%' is not a valid port number (1-65535)!RS! & goto end )
if %PORT_CHECK% GTR 65535 ( echo !YL!Error: '%PORT%' is not a valid port number (1-65535)!RS! & goto end )

set "FOUND=0"
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr /i "LISTENING"') do (
  set "FOUND=1"
  set "PROCNAME="
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do set "PROCNAME=%%~p"
  if "!PROCNAME!"=="" set "PROCNAME=(unknown)"
  echo.
  echo   Port !BD!!PORT!!RS! is in use:
  echo.
  echo   !BD!PID:!RS!   %%e
  echo   !BD!Name:!RS!  !PROCNAME!
  echo   !BD!Addr:!RS!  %%b
  echo.
  taskkill /PID %%e /F >nul 2>&1
  if errorlevel 1 (
    echo !YL!Could not kill PID %%e — try running as Administrator.!RS!
  ) else (
    echo !GR!Killed.!RS!
  )
)
if "!FOUND!"=="0" echo !DM!Nothing running on port %PORT%!RS!

:: -------------------------------------------------------
:end
endlocal
\r