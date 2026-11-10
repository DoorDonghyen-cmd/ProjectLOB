param([ValidateSet('rules','climb','ui','replay','opening','opening_ui')][string]$Mode='rules',[string]$Label='final',[string]$Guns='single,burst,scatter,heavy,amplifier',[int]$Seed=731042)
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/focus_build_20261103/'+$Mode+'_'+$Label)
if($Mode -in @('opening','opening_ui')){$runtime=Join-Path $repo ('qa_runtime/opening_build_20261108/'+$Mode+'_'+$Label)}
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns;$env:QA_SEED=$Seed
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/focus_build_'+$Mode+'.gd'))
if($Mode -in @('ui','opening_ui')){$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}else{$arguments+='--headless'}
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(25)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Focus build stopped: $errors"}
}
$process.WaitForExit();$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8;$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 8)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'FOCUS BUILD COMPLETE checks=\d+ failures=0'){throw "Focus build failed; see $stdout $errors"}
