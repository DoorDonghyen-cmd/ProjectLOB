param([ValidateSet('baseline','order')][string]$Mode='baseline')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo 'qa_runtime/weapon_roles_20261106'
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$name=if($Mode -eq 'order'){'order_probe'}else{'probe'}
$script=Join-Path $repo ('docs/qa/reports/weapon_roles_2026-11-06/'+$name+'.gd')
$stdout=Join-Path $runtime ($Mode+'_stdout.log');$stderr=Join-Path $runtime ($Mode+'_stderr.log')
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--headless','--path',('"'+$project+'"'),'--script',('"'+$script+'"')) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
$errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 4)
if($p.ExitCode -ne 0 -or $errors -match 'ERROR:|SCRIPT ERROR|Parse Error' -or $result -notmatch 'PROBE COMPLETE.*failures=0'){throw "Role probe failed: $runtime"}
