$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$workspace = Split-Path -Parent (Split-Path -Parent $repo)
$engine = Join-Path $workspace '.tmp\godot-4.7\Godot_v4.7-stable_win64.exe'
if ($env:GODOT_EXE) { $engine = $env:GODOT_EXE }
if (-not (Test-Path -LiteralPath $engine)) { throw 'Godot 4.7 was not found.' }
# Art-only scene contains no save or campaign object.
$env:APPDATA = Join-Path $repo 'qa_runtime\outfit_preview\Roaming'
$env:LOCALAPPDATA = Join-Path $repo 'qa_runtime\outfit_preview\Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
# This launcher is opened by the player to inspect the art interactively.
Start-Process -FilePath $engine -ArgumentList @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', 'res://redesign/outfit_preview.tscn') -WorkingDirectory $project
