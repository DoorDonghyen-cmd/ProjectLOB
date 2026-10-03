@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\connect_pixellab.ps1" %*
set "connect_result=%errorlevel%"
if not "%connect_result%"=="0" echo PixelLab setup failed. The error is shown above; your key was not printed.
pause
exit /b %connect_result%
