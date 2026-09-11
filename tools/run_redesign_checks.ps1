param([ValidateSet('rules','campaign','visual','regression','ui_campaign')][string]$Mode = 'rules')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\redesign\$Mode"
if ($Mode -eq 'ui_campaign') {
    $runtime = Join-Path $repo 'qa_runtime\redesign\campaign_ui\final_retry'
    $env:QA_CAMPAIGN_SOURCE = Join-Path $repo 'qa_runtime\redesign\campaign\Roaming\Godot\app_userdata\Last on Board - Core Redesign\redesign_campaign_report.json'
}
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_TEST_SUMMARY_PATH = Join-Path $runtime 'summary.json'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe'
$script = if ($Mode -eq 'regression') { 'res://tests/run_all.gd' } else { "res://tests/redesign_${Mode}_runner.gd" }
$argsForGodot = @('--path', ('"{0}"' -f $project), '--script', $script)
if ($Mode -in @('visual','ui_campaign')) { $argsForGodot += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
else { $argsForGodot += '--headless' }
$process = Start-Process -FilePath $godot -ArgumentList $argsForGodot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
if (-not $process.WaitForExit(300000)) { Stop-Process -Id $process.Id -Force; throw 'QA timeout' }
$process.WaitForExit()
$output = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stdout.log')
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stderr.log')
if ($Mode -eq 'regression') { Write-Output (($output -split "`n" | Select-Object -Last 8) -join "`n") }
else { Write-Output $output }
if ($errors -cmatch 'SCRIPT ERROR|Parse Error|\bFAIL\b|Assertion failed' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $output -match '[1-9][0-9]* failed|실패: [1-9]|won=false') { throw "QA failed: $errors" }
$completion = switch ($Mode) { 'rules' { 'REDESIGN RULES:' }; 'visual' { 'REDESIGN VISUAL:' }; 'campaign' { 'CAMPAIGN burst seed=901' }; 'regression' { '테스트 요약' }; 'ui_campaign' { 'REDESIGN UI CAMPAIGN:' } }
if (-not $output.Contains($completion)) { throw 'QA completion marker missing' }
Write-Output "Artifacts: $runtime"
