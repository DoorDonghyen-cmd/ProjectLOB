param([ValidateSet('rules','ui','gallery','reactions')][string]$Mode='rules')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/surface_fx_20261106/'+$Mode)
if($Mode -eq 'reactions'){$runtime=Join-Path $repo 'qa_runtime/enemy_hit_feedback_20261108/reactions'}
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/surface_fx_'+$Mode+'.gd'))
if($Mode -eq 'rules'){$arguments+='--headless'}else{$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(8)
while(-not $p.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $p.Id;throw "Surface effects stopped: $errors"}
}
$p.WaitForExit();$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or $result -notmatch 'SURFACE FX .*COMPLETE' -or $result -match 'failures=[1-9]'){throw "Surface effects failed: $runtime"}
