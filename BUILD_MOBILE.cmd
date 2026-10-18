@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_mobile_release.ps1" %*
exit /b %errorlevel%
