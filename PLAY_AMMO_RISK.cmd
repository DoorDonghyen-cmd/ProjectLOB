@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\ammo_risk_sample.ps1"
if errorlevel 1 pause
