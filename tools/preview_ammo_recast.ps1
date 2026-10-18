param([switch]$Check)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo 'qa_runtime/ammo_recast'
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$import=Start-Process -FilePath $engine -ArgumentList @('--headless','--editor','--path',('"{0}"' -f $project),'--import','--quit') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $runtime 'import.log') -RedirectStandardError (Join-Path $runtime 'import_errors.log')
if ($import.ExitCode -ne 0 -or (Get-Content -Raw (Join-Path $runtime 'import_errors.log')) -match 'SCRIPT ERROR|Parse Error') {throw 'Preview import failed'}
$arguments=@('--path',('"{0}"' -f $project),'--rendering-method','gl_compatibility','--resolution','1280x800')
if ($Check) {$arguments+=@('--script','res://tests/ammo_recast_preview_runner.gd','--position','-2000,-2000')}
else {$arguments+='res://redesign/samples/ammo_recast.tscn'}
if (-not $Check) {
	$arguments=@('--path',$project,'--rendering-method','gl_compatibility','--resolution','1280x800','res://redesign/samples/ammo_recast.tscn')
    & $engine @arguments
    exit $LASTEXITCODE
}
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline=[DateTime]::UtcNow.AddMinutes(2)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw $stderr
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Preview failed: $errors"}
}
$result=Get-Content -Raw $stdout
$process.WaitForExit()
$errors=Get-Content -Raw $stderr
Write-Output $result
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error' -or $result -notmatch 'AMMO RECAST PREVIEW COMPLETE failures=0') {throw "Preview check failed: $errors"}
