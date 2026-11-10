param([ValidateSet('probe','climb','rules','ui','replay')][string]$Mode='probe',[string]$Label='baseline')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/core_choice_20261103/'+$Mode+'_'+$Label)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/core_choice_'+$Mode+'.gd'))
if($Mode -eq 'ui'){$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}else{$arguments+='--headless'}
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(25)
while(-not $p.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $p.Id;throw "Core choice stopped: $errors"}
}
$p.WaitForExit();$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8;$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 6)
if($p.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'CORE CHOICE COMPLETE.*failures=0'){throw "Core choice failed; see $stdout $errors"}
