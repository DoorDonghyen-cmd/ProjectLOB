param([ValidateSet('rules','ui','probe','contracts','restart','visual')][string]$Mode='rules',[string]$Guns='single,burst,scatter,heavy,amplifier',[string]$RunTag='integrated',[ValidateSet('write','read')][string]$Stage='write')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/campaign_magazine_20261101/'+$RunTag+'/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns
$env:QA_RESUME_PHASE=$Stage
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/campaign_magazine_'+$Mode+'.gd'))
if($Mode -in @('rules','contracts')){$arguments+='--headless'}
else{$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
if($Mode -eq 'restart'){$stdout=Join-Path $runtime ($Stage+'_stdout.log');$stderr=Join-Path $runtime ($Stage+'_stderr.log')}
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Id | Set-Content -LiteralPath (Join-Path $runtime "process_id.txt")
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(25)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if((Test-Path -LiteralPath (Join-Path $runtime 'stop.request')) -or $errors -match 'ERROR:|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Campaign check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 8)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -match 'failures=[1-9]' -or $result -notmatch 'COMPLETE'){throw "Campaign check failed (exit=$($process.ExitCode)): $errors"}
