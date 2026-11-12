param([ValidateSet('poses','live','rules','compare','outfits')][string]$Mode='poses',[string]$Label='before')
$ErrorActionPreference='Stop'
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') {throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo "qa_runtime/spike_motion_20261106/$Label"
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"{0}"' -f $project),'--script',"res://tests/spike_motion_$Mode.gd")
if ($Mode -eq 'rules') {$arguments+='--headless'} else {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1600x800','--position','-2000,-2000')}
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(6)
while (-not $p.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if ($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $p.Id;throw "Spike motion stopped: $errors"}
}
$p.WaitForExit();$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 4)
if ($p.ExitCode -ne 0 -or $result -notmatch 'SPIKE MOTION .*COMPLETE' -or $result -match 'failures=[1-9]') {throw "Spike motion failed: $runtime"}
