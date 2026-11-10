@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\open_pixelfx.ps1" %*
exit /b %errorlevel%
