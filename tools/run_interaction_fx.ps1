param([ValidateSet('ui','movie')][string]$Mode='ui')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/interaction_fx_20261106/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/interaction_fx_'+$Mode+'.gd'),'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(8)
while(-not $p.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){$null=$p.WaitForExit(1000);if(-not $p.HasExited){Stop-Process -Id $p.Id};throw ('Interaction feedback stopped: '+(Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8))}
}
$p.WaitForExit();$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or $result -notmatch 'INTERACTION FX .*COMPLETE' -or $result -match 'failures=[1-9]'){throw "Interaction feedback failed: $runtime"}
