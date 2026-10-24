@echo off
setlocal
cd /d "%~dp0"
title Stereopsis VR
echo.
echo   Stereopsis VR - depth vision test and training
echo   -----------------------------------------------
echo   1. Connect your headset and controllers.
echo   2. Type a short name or nickname (letters and numbers only).
echo      Your results are saved in the "results" folder next to this file.
echo.
set "NAME="
set /p "NAME=  Name or nickname (Enter = player): "
if not defined NAME set "NAME=player"
if not exist "%~dp0results" mkdir "%~dp0results"

if not defined STEAMVR_HOME set "STEAMVR_HOME=C:\Program Files (x86)\Steam\steamapps\common\SteamVR"
tasklist /FI "IMAGENAME eq vrmonitor.exe" /NH | find /I "vrmonitor.exe" >nul
if not errorlevel 1 goto waitVR
if exist "%STEAMVR_HOME%\bin\win64\vrmonitor.exe" (
  start "" "%STEAMVR_HOME%\bin\win64\vrmonitor.exe"
) else (
  echo   SteamVR was not found in its default folder. If you use it, start it now.
)
echo   Waiting for SteamVR (up to 45 seconds)...
set /A retries=0
:waitVR
tasklist /FI "IMAGENAME eq vrcompositor.exe" /NH | find /I "vrcompositor.exe" >nul
if not errorlevel 1 goto ready
set /A retries+=1
if %retries% GEQ 45 goto noSteamVR
timeout /T 1 /NOBREAK >nul
goto waitVR

:noSteamVR
echo.
echo   SteamVR is not running. The app will use whatever OpenXR runtime is active
echo   on this PC (e.g. Meta Quest Link). If nothing shows up in the headset,
echo   close the app, start SteamVR, check it sees the headset, and run this again.
pause

:ready
start "" "%~dp0StereopsisVR.exe" --xr-mode on --log-file "%~dp0results\stereopsis.log" -- --vr "--partecipante=%NAME%"
exit /b
