@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\open_gate_review.ps1" %*
if errorlevel 1 pause
