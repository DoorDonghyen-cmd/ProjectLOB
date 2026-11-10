param([ValidateSet('stress','flow')][string]$Mode='stress',[string]$Label='final')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid report label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo "qa_runtime/presentation_integration_20261106/$Mode-$Label"
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime;$env:QA_INTEGRATION_MODE=$Mode
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'),'--script','res://tests/presentation_integration.gd','--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(15)
while(-not $p.WaitForExit(500)) {
 $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){$null=$p.WaitForExit(1000);if(-not $p.HasExited){Stop-Process -Id $p.Id};throw ('Integration stopped: '+(Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8))}
}
$p.WaitForExit();$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or $result -notmatch 'PRESENTATION INTEGRATION COMPLETE.*failures=0'){throw "Integration failed: $runtime"}
