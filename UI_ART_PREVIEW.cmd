@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\preview_ammo_recast.ps1"
endlocal
