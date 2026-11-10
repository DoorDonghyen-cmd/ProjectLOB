param([ValidateSet('climb','audit','rules','ui','restart','probe','replay')][string]$Mode='rules',[string]$Label='final',[string]$Guns='single,burst,scatter,heavy,amplifier',[int]$Seed=731042,[ValidateSet('safe','elite','avoid_elite')][string]$Route='safe',[ValidateSet('write','read')][string]$Stage='write',[ValidateSet('original','focus')][string]$Build='original')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/fire_control_20261102/'+$Mode+'_'+$Label)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns;$env:QA_SEED=$Seed;$env:QA_ROUTE=$Route;$env:QA_RESUME_PHASE=$Stage
$env:QA_BUILD=$Build
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime ($Stage+'_stdout.log');$stderr=Join-Path $runtime ($Stage+'_stderr.log')
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/fire_control_'+$Mode+'.gd'))
if($Mode -in @('climb','audit','rules','probe','replay')){$arguments+='--headless'}else{$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(25)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Fire control stopped: $errors"}
}
$process.WaitForExit();$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8;$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 8)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'FIRE CONTROL COMPLETE checks=\d+ failures=0'){throw "Fire control failed; see $stdout $errors"}
