param([ValidateSet('visual','ui_campaign','rules')][string]$Mode = 'visual')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\chain\$Mode"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:CHAIN_CAMPAIGN_SOURCE = Join-Path $repo 'docs\qa\reports\chain_ui_source_2026-09-13.json'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe'
$argsForGodot = @('--path', ('"{0}"' -f $project), '--script', "res://tests/chain_${Mode}_runner.gd")
if ($Mode -eq 'rules') { $argsForGodot += '--headless' }
else { $argsForGodot += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
$process = Start-Process -FilePath $godot -ArgumentList $argsForGodot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
if (-not $process.WaitForExit(300000)) { Stop-Process -Id $process.Id -Force; throw 'QA timeout' }
$process.WaitForExit()
$output = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stdout.log')
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stderr.log')
Write-Output $output
if ($errors -match 'SCRIPT ERROR|Parse Error|\bFAIL\b|Assertion failed' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $output -notmatch 'CHAIN[ _]') { throw "QA failed: $errors" }
Write-Output "Artifacts: $runtime"
