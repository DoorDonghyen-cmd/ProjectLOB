@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_game.ps1" -EarlyPartsTrial
if errorlevel 1 pause
