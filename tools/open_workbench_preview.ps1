$ErrorActionPreference='Stop'
$taskRepo=Split-Path -Parent $PSScriptRoot
$taskQa=Join-Path $taskRepo 'qa_runtime/workbench_theme_20261104/interactive'
$env:APPDATA=Join-Path $taskQa 'Roaming'
$env:LOCALAPPDATA=Join-Path $taskQa 'Local'
New-Item -ItemType Directory -Force -Path $taskQa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$taskProject=(Get-ChildItem -LiteralPath $taskRepo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$taskArgs=@('--path',('"'+$taskProject+'"'),'--rendering-method','gl_compatibility','--resolution','1280x800','--position','60,60','res://redesign/samples/workbench_theme/preview.tscn')
Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $taskArgs -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskQa 'stdout.log') -RedirectStandardError (Join-Path $taskQa 'stderr.log') | Out-Null
