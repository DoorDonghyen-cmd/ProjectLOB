param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
if (-not $project) { throw 'The Godot project is missing.' }
$workspace = Split-Path -Parent (Split-Path -Parent $repo)
$godot = Join-Path $workspace '.tmp\godot-4.7\Godot_v4.7-stable_win64.exe'
if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE)) { $godot = $env:GODOT_EXE }
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot 4.7 was not found. Set GODOT_EXE or open project.godot in Godot and press F6 on redesign/main.tscn.' }
if ($CheckOnly) {
    Write-Output "Engine: $godot"
    Write-Output "Project: $project"
    Write-Output 'Scene: res://redesign/main.tscn'
    exit 0
}
# This is the player's interactive window; use their normal save location.
Start-Process -FilePath $godot -ArgumentList @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility') -WorkingDirectory $project
