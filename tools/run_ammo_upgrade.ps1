param([ValidateSet('ui','balance','recovery')][string]$Mode='ui',[string]$Label='final',[string]$Guns='single,burst,scatter,heavy,amplifier',[string]$Seeds='17',[string]$Outfit='carrier',[switch]$UpgradeRoute)
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$taskRepo=Split-Path -Parent $PSScriptRoot
$taskQa=Join-Path $taskRepo ('qa_runtime/ammo_upgrade_single_20261106/'+$Label)
$taskProject=(Get-ChildItem -LiteralPath $taskRepo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$env:APPDATA=Join-Path $taskQa 'Roaming';$env:LOCALAPPDATA=Join-Path $taskQa 'Local';$env:QA_OUTPUT_DIR=$taskQa
$env:QA_GUNS=$Guns;$env:QA_SEEDS=$Seeds
$env:QA_OUTFIT=$Outfit;$env:QA_UPGRADE_ROUTE=if($UpgradeRoute){'1'}else{'0'}
New-Item -ItemType Directory -Force -Path $taskQa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$taskScript=switch($Mode){'ui'{'res://tests/ammo_upgrade_live.gd'} 'balance'{'res://tests/ammo_upgrade_balance.gd'} 'recovery'{'res://tests/ammo_upgrade_recovery.gd'}}
$taskArgs=@('--path',('"'+$taskProject+'"'),'--script',$taskScript)
if($Mode -eq 'ui'){$taskArgs+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}else{$taskArgs+='--headless'}
$taskProcess=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $taskArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskQa 'stdout.log') -RedirectStandardError (Join-Path $taskQa 'stderr.log')
$null=$taskProcess.Handle;$taskDeadline=[DateTime]::UtcNow.AddMinutes(25)
while(-not $taskProcess.WaitForExit(500)){
 $taskErrors=Get-Content -Raw (Join-Path $taskQa 'stderr.log')
 if($taskErrors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $taskDeadline){Stop-Process -Id $taskProcess.Id;throw $taskErrors}
}
$taskProcess.WaitForExit()
Get-Content (Join-Path $taskQa 'stdout.log') -Tail 7
Get-Content (Join-Path $taskQa 'stderr.log') -Tail 6
if($taskProcess.ExitCode -ne 0 -or (Get-Content -Raw (Join-Path $taskQa 'stdout.log')) -notmatch 'AMMO UPGRADE (LIVE|BALANCE|RECOVERY) COMPLETE checks=\d+ failures=0'){throw ('Ammo upgrade check failed: '+$taskQa)}
