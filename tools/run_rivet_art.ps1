param([ValidateSet('poses','ui','import','compare','preview')][string]$Mode='poses')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/rivet_art_20261106/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'))
if($Mode -eq 'import') {$arguments+=@('--headless','--editor','--import','--quit')}
else {$arguments+=@('--script',('res://tests/rivet_art_'+$Mode+'.gd'),'--rendering-method','gl_compatibility','--resolution','1280x960','--position','-2000,-2000')}
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(8)
while(-not $p.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $p.Id;throw "Rivet art stopped: $errors"}
}
$p.WaitForExit()
$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or ($Mode -ne 'import' -and $result -notmatch 'RIVET ART .*COMPLETE') -or $result -match 'failures=[1-9]') {throw "Rivet art failed: $runtime"}
