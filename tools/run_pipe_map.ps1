param([string]$Label='integration_20261101',[ValidateSet('integration','preview')][string]$Mode='integration')
$ErrorActionPreference='Stop'
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid label'}
$repo=Split-Path -Parent $PSScriptRoot
$project=Join-Path $repo '새-게임-프로젝트'
$runtime=Join-Path $repo ('qa_runtime/maps/pipe_'+$Label)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_ROUTE_REPORT=Join-Path $repo 'qa_runtime/campaign_magazine_20261101/integrated/rules/balance.json'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$test=if($Mode -eq 'preview'){'res://tests/pipe_map_preview.gd'}else{'res://tests/pipe_map_ui.gd'}
$arguments=@('--path',('"'+$project+'"'),'--script',$test,'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(15)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Pipe map check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 10)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:|FAIL:' -or $result -match 'failures=[1-9]|FAIL:' -or $result -notmatch 'PIPE MAP COMPLETE'){throw "Pipe map check failed: $errors"}
Write-Output "Artifacts: $runtime"
