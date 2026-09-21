param([string]$Godot = $env:GODOT_EXE)
if (-not $Godot) { $Godot = 'D:\ProjectLoB\qa_runtime\tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' }
$root = Split-Path $PSScriptRoot -Parent
$project = Get-ChildItem -LiteralPath $root -Recurse -Filter 'project.godot' | Select-Object -First 1 -ExpandProperty DirectoryName
$output = Join-Path $root 'qa_output\horde_reinforcement'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$env:QA_OUTPUT_DIR = $output
$runtime = Join-Path $root 'qa_runtime\horde_reinforcement_home'
$env:GODOT_USER_HOME = $runtime
$env:APPDATA = Join-Path $runtime 'appdata'
$env:LOCALAPPDATA = Join-Path $runtime 'localappdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:GODOT_USER_HOME | Out-Null
& $Godot --headless --path $project --script res://tests/horde_reinforcement_runner.gd
exit $LASTEXITCODE
