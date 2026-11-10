param([switch]$Check,[string]$Label='review')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid report label'}
$taskRepo=Split-Path -Parent $PSScriptRoot
$taskQa=Join-Path $taskRepo ('qa_runtime/ammo_upgrade_single_20261106/'+$Label)
$taskProject=(Get-ChildItem -LiteralPath $taskRepo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$taskEngine='D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$env:APPDATA=Join-Path $taskQa 'Roaming'
$env:LOCALAPPDATA=Join-Path $taskQa 'Local'
$env:QA_OUTPUT_DIR=$taskQa
New-Item -ItemType Directory -Force -Path $taskQa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$taskArgs=@('--path',('"'+$taskProject+'"'),'--rendering-method','gl_compatibility','--resolution','1280x800')
if($Check){$taskArgs+=@('--script','res://tests/ammo_upgrade_review.gd','--position','-2000,-2000')}
else{$taskArgs+=@('res://redesign/samples/ammo_upgrade/preview.tscn','--position','60,60')}
$taskProcess=Start-Process -FilePath $taskEngine -ArgumentList $taskArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskQa 'stdout.log') -RedirectStandardError (Join-Path $taskQa 'stderr.log')
if(-not $Check){
 Write-Output ('Opened review; F1 reset, F2 grade study. Logs: '+$taskQa)
 $null=$taskProcess.Handle
 $taskProcess.WaitForExit()
 exit $taskProcess.ExitCode
}
$null=$taskProcess.Handle
$taskDeadline=[DateTime]::UtcNow.AddMinutes(3)
while(-not $taskProcess.WaitForExit(500)){
 $taskErrors=Get-Content -Raw (Join-Path $taskQa 'stderr.log')
 if($taskErrors -match 'Parse Error|SCRIPT ERROR' -or [DateTime]::UtcNow -gt $taskDeadline){Stop-Process -Id $taskProcess.Id;throw $taskErrors}
}
$taskProcess.WaitForExit()
Get-Content (Join-Path $taskQa 'stdout.log') -Tail 5
Get-Content (Join-Path $taskQa 'stderr.log') -Tail 6
if($taskProcess.ExitCode -ne 0 -or (Get-Content -Raw (Join-Path $taskQa 'stdout.log')) -notmatch 'AMMO UPGRADE LIVE COMPLETE checks=\d+ failures=0'){throw 'Ammo upgrade review failed'}
