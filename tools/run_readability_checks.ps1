param([ValidateSet('visual','ui_campaign','rules')][string]$Mode = 'visual')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\readability\$Mode"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot = (Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1).FullName
if (-not $godot) { throw 'Godot 4.7 console executable not found under OneDrive\Desktop.' }
$previousErrorAction = $ErrorActionPreference
if ($Mode -eq 'ui_campaign') {
    $campaignSource = Join-Path $runtime 'source'
    New-Item -ItemType Directory -Force -Path $campaignSource | Out-Null
    $env:QA_OUTPUT_DIR = $campaignSource
    $env:QA_POLICY = 'supply'
    $env:QA_EXCHANGE = 'optional'
    $ErrorActionPreference = 'Continue'
    & $godot --headless --path $project --script 'res://tests/readability_campaign_runner.gd' 1> (Join-Path $runtime 'source.stdout.log') 2> (Join-Path $runtime 'source.stderr.log')
    $sourceExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    $sourceOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'source.stdout.log')
    $sourceErrors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'source.stderr.log')
    Write-Output $sourceOutput
    if ($sourceExitCode -ne 0 -or $sourceErrors -match 'SCRIPT ERROR|Parse Error|\bFAIL\b|Assertion failed' -or $sourceOutput -notmatch 'READABILITY CAMPAIGN COMPLETE') { throw "Campaign source failed: $sourceErrors" }
    $env:READABILITY_CAMPAIGN_SOURCE = Join-Path $campaignSource 'campaign_report.json'
}
$argsForGodot = @('--path', $project, '--script', "res://tests/readability_${Mode}_runner.gd")
if ($Mode -eq 'rules') { $argsForGodot += '--headless' }
else { $argsForGodot += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$ErrorActionPreference = 'Continue'
& $godot @argsForGodot 1> $stdout 2> $stderr
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction
$output = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stdout.log')
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stderr.log')
Write-Output $output
if ($errors -match 'SCRIPT ERROR|Parse Error|\bFAIL\b|Assertion failed' -or $exitCode -ne 0 -or $output -notmatch 'READABILITY[ _]') { throw "QA failed: $errors" }
Write-Output "Artifacts: $runtime"
