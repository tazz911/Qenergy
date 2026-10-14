@echo off
title EnergyIQ Meter Simulator
cd /d "%~dp0"
echo ============================================
echo   EnergyIQ - Fake Smart Meter
echo   (in the app: tap your device to see Serial + API key)
echo ============================================
echo.
:ask_serial
set "SERIAL="
set /p SERIAL=Serial number (e.g. ESP32-001): 
if "%SERIAL%"=="" goto ask_serial
:ask_key
set "APIKEY="
set /p APIKEY=API key (right-click to paste): 
if "%APIKEY%"=="" goto ask_key
echo.
echo Sending readings every 5 seconds. Close this window to stop.
echo.
python -u meter_simulator.py --device %SERIAL%:%APIKEY% --interval 5 --spike-every 24
pause
