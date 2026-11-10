@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\open_supply_review.ps1" %*
if errorlevel 1 pause
