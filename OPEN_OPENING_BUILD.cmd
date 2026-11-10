@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_game.ps1" -OpeningBuildComparison
if errorlevel 1 pause
