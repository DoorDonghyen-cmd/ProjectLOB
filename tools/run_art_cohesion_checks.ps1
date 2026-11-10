param([ValidateSet('rules','ui')][string]$Mode='ui')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=Join-Path $repo '새-게임-프로젝트'
$runtime=Join-Path $repo 'qa_runtime/art_cohesion'
$output=Join-Path $repo 'docs/qa/reports/assets/art_cohesion_2026-10-24'
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$output
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$output | Out-Null
$engine='D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$runner=if($Mode -eq 'ui'){'art_cohesion_ui_runner'}else{'reactor_rules_runner'}
$argsList=@('--path',('"{0}"' -f $project),'--script',"res://tests/$runner.gd")
if($Mode -eq 'ui'){$argsList+=@('--rendering-method','gl_compatibility','--position','-2000,-2000')}else{$argsList+='--headless'}
$stdout=Join-Path $output "$Mode.log"
$stderr=Join-Path $output "$Mode-errors.log"
$process=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline=[DateTime]::UtcNow.AddMinutes(6)
while(-not $process.WaitForExit(500)){
  $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
  if($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Art cohesion QA stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -match 'FAIL:' -or $result -notmatch 'COMPLETE checks=\d+ failures=0'){throw "Art cohesion QA failed: $errors"}
