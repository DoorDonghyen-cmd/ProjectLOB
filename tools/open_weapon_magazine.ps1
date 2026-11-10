$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo 'qa_runtime/fire_heat_20261102/interactive'
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"{0}"' -f $project),'res://redesign/samples/fire_heat/screen.tscn','--rendering-method','gl_compatibility','--resolution','1280x800')
Start-Process -FilePath 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -WorkingDirectory $repo
