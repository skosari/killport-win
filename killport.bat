@echo off
setlocal enabledelayedexpansion

set VERSION=1.2.0
set REPO=skosari/killport-win
set RAW=https://raw.githubusercontent.com/%REPO%/main

if "%~1"=="" goto no_args
if /i "%~1"=="list" goto list_ports
if /i "%~1"=="update" goto do_update
goto kill_port

:: -------------------------------------------------------
:no_args
echo killport v%VERSION%
echo Usage: killport ^<port^>
echo        killport list
echo        killport update
echo.
call :check_update
goto list_ports

:: -------------------------------------------------------
:check_update
curl -fsSL --max-time 2 "%RAW%/VERSION" -o "%TEMP%\killport_remote_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_remote_ver.txt" exit /b
set /p REMOTE_VER=<"%TEMP%\killport_remote_ver.txt"
del "%TEMP%\killport_remote_ver.txt" >nul 2>&1
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
  set ADDR=%%b
  set PID=%%e
  set PROCNAME=
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do (
    set PROCNAME=%%~p
  )
  if "!PROCNAME!"=="" set PROCNAME=(unknown)
  echo   %%b	!PROCNAME!	%%e
)
echo.
goto end

:: -------------------------------------------------------
:do_update
echo Checking for updates...
curl -fsSL --max-time 5 "%RAW%/VERSION" -o "%TEMP%\killport_remote_ver.txt" >nul 2>&1
if not exist "%TEMP%\killport_remote_ver.txt" (
  echo Could not reach GitHub. Check your connection.
  goto end
)
set /p REMOTE_VER=<"%TEMP%\killport_remote_ver.txt"
del "%TEMP%\killport_remote_ver.txt" >nul 2>&1
set REMOTE_VER=%REMOTE_VER: =%
if "%REMOTE_VER%"=="%VERSION%" (
  echo Already up to date ^(v%VERSION%^)
  goto end
)
echo Updating %VERSION% -^> %REMOTE_VER%...
curl -fsSL "%RAW%/killport.bat" -o "%~f0.tmp" >nul 2>&1
if errorlevel 1 (
  echo Download failed. Try running as Administrator.
  goto end
)
move /y "%~f0.tmp" "%~f0" >nul 2>&1
echo Updated to v%REMOTE_VER%. Run killport to confirm.
goto end

:: -------------------------------------------------------
:kill_port
set PORT=%~1

:: Validate port is numeric 1-65535
set /a PORT_CHECK=%PORT% 2>nul
if "%PORT_CHECK%"=="0" (
  echo Error: '%PORT%' is not a valid port number ^(1-65535^)
  goto end
)
if %PORT_CHECK% LSS 1 (
  echo Error: '%PORT%' is not a valid port number ^(1-65535^)
  goto end
)
if %PORT_CHECK% GTR 65535 (
  echo Error: '%PORT%' is not a valid port number ^(1-65535^)
  goto end
)

set FOUND=0
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr /i "LISTENING"') do (
  set FOUND=1
  set PID=%%e
  set PROCNAME=
  set PROCPATH=
  for /f "tokens=1 delims=," %%p in ('tasklist /fi "PID eq %%e" /fo csv /nh 2^>nul') do (
    set PROCNAME=%%~p
  )
  if "!PROCNAME!"=="" set PROCNAME=(unknown)
  echo Port %PORT% is in use:
  echo.
  echo   PID:   %%e
  echo   Name:  !PROCNAME!
  echo   Addr:  %%b
  echo.
  taskkill /PID %%e /F >nul 2>&1
  if errorlevel 1 (
    echo Could not kill PID %%e - try running as Administrator.
  ) else (
    echo Killed.
  )
)

if "%FOUND%"=="0" (
  echo Nothing running on port %PORT%
)

:: -------------------------------------------------------
:end
endlocal
