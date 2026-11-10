$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64.exe'
if ($env:GODOT_EXE) { $engine = $env:GODOT_EXE }
$env:APPDATA = Join-Path $repo 'qa_runtime\central_guard_concepts\play\Roaming'
$env:LOCALAPPDATA = Join-Path $repo 'qa_runtime\central_guard_concepts\play\Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
# Player-invoked interactive viewer.
Start-Process -FilePath $engine -ArgumentList @('--path',('"{0}"' -f $project),'--rendering-method','gl_compatibility','res://redesign/central_guard_concept_preview.tscn') -WorkingDirectory $project -WindowStyle Normal
