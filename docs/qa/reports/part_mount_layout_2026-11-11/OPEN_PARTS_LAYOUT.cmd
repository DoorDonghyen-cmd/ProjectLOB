@echo off
setlocal
for %%I in ("%~dp0..\..\..\..") do set "LOB_REPO=%%~fI"
for /d %%P in ("%LOB_REPO%\*") do if exist "%%~fP\project.godot" set "LOB_PROJECT=%%~fP"
set "LOB_GODOT=D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64.exe"
if not defined LOB_PROJECT exit /b 2
if not exist "%LOB_GODOT%" exit /b 2
set "APPDATA=%LOB_REPO%\qa_runtime\part_mount_layout_20261111\Roaming"
set "LOCALAPPDATA=%LOB_REPO%\qa_runtime\part_mount_layout_20261111\Local"
set "LOB_PREVIEW_SIZE="
if /i "%~1"=="mobile" set "LOB_PREVIEW_SIZE=--mobile"
start "" "%LOB_GODOT%" --path "%LOB_PROJECT%" --rendering-method gl_compatibility --script "%~dp0layout_preview.gd" -- --preview %LOB_PREVIEW_SIZE%
