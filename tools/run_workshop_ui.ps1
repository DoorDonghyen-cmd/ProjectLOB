param([string]$Label="final")
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$qa=Join-Path $repo ('qa_runtime/ui_standard_20261104/'+$Label)
$env:APPDATA=Join-Path $qa 'Roaming'
$env:LOCALAPPDATA=Join-Path $qa 'Local'
$env:QA_OUTPUT_DIR=$qa
New-Item -ItemType Directory -Force -Path $qa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$script='res://tests/workshop_standard_ui.gd'
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--path',('"'+$project+'"'),'--script',('"'+$script+'"'),'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qa 'stdout.log') -RedirectStandardError (Join-Path $qa 'stderr.log')
$null=$p.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(4)
while(-not $p.WaitForExit(500)) {
 $errors=Get-Content -Raw (Join-Path $qa 'stderr.log')
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $p.Id;throw $errors}
}
$p.WaitForExit()
Get-Content (Join-Path $qa 'stdout.log') -Tail 8
Get-Content (Join-Path $qa 'stderr.log') -Tail 5
Write-Output ('Exit '+$p.ExitCode)
$result=Get-Content -Raw (Join-Path $qa 'stdout.log')
if($p.ExitCode -ne 0 -or $result -notmatch 'WORKSHOP STANDARD COMPLETE checks=\d+ failures=0'){throw 'Workshop UI check failed'}
