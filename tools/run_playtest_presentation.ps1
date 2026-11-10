param([string]$Label='baseline',[string]$Script='res://tests/playtest_presentation_ui.gd')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $repo ('qa_runtime/playtest_20261102/'+$Label)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$arguments=@('--path',('"'+(Join-Path $repo '새-게임-프로젝트')+'"'),'--script',('"'+$Script+'"'),'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(10)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Presentation check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 10)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'PRESENTATION COMPLETE checks=\d+ failures=0'){throw "Presentation check failed; see $stdout $errors"}
