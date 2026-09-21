param([string]$Godot = $env:GODOT_EXE)
if (-not $Godot) { $Godot = 'D:\ProjectLoB\qa_runtime\tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' }
$root = Split-Path $PSScriptRoot -Parent
$project = Get-ChildItem -LiteralPath $root -Recurse -Filter 'project.godot' | Select-Object -First 1 -ExpandProperty DirectoryName
$runtime = Join-Path $root 'qa_runtime\horde_ui'
$env:APPDATA = Join-Path $runtime 'appdata'
$env:LOCALAPPDATA = Join-Path $runtime 'localappdata'
$env:QA_OUTPUT_DIR = Join-Path $runtime 'artifacts'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:QA_OUTPUT_DIR | Out-Null
& $Godot --path $project --script res://tests/horde_ui_runner.gd --rendering-method gl_compatibility --position '-2000,-2000'
exit $LASTEXITCODE
