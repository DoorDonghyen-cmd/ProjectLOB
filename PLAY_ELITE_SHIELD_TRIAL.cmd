@echo off
setlocal
choice /c AB /n /m "A - Pierce bonus   B - Pierce only with timed opening: "
if errorlevel 3 exit /b
if not errorlevel 1 exit /b
if errorlevel 2 (
    set "ELITE_TRIAL_VARIANT=strict"
) else (
    set "ELITE_TRIAL_VARIANT=weak"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_combat_trial.ps1" -Scenario elite_shield -Variant %ELITE_TRIAL_VARIANT%
