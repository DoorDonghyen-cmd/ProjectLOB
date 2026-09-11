param(
    [ValidateSet('regression', 'ammo', 'campaign', 'simulator', 'visual', 'experience')][string]$Mode = 'regression',
    [ValidateSet('beginner', 'aggressive', 'conservative', 'experimental')][string]$Profile = 'beginner',
    [ValidateRange(1, 2147483647)][int]$Seed = 424242,
    [ValidatePattern('^[a-zA-Z0-9_-]{0,32}$')][string]$RunLabel = '',
    [string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\preart_20260911\$Mode"
if ($Mode -eq 'experience') { $runtime = Join-Path $runtime "$Seed-$Profile" }
if ($RunLabel) { $runtime = Join-Path $runtime $RunLabel }
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$env:APPDATA = Join-Path $runtime 'appdata'
$env:LOCALAPPDATA = Join-Path $runtime 'localappdata'
$env:GODOT_USER_HOME = Join-Path $runtime 'godot_home'
$env:QA_OUTPUT_DIR = Join-Path $runtime 'artifacts'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:GODOT_USER_HOME, $env:QA_OUTPUT_DIR | Out-Null
$env:QA_TEST_SUMMARY_PATH = Join-Path $runtime 'summary.json'
$env:QA_TARGET_SECTIONS = '5'
$env:QA_GAMEPLAY_SEED = [string]$Seed
$env:QA_PROFILE = $Profile
$env:QA_TARGET_ENCOUNTERS = '6'
$env:QA_REPORT_DIR = Join-Path $env:QA_OUTPUT_DIR 'reports'
$env:QA_CAPTURE = 'false'
$env:QA_COMMIT = (git -C $repo rev-parse HEAD).Trim()
$scripts = @{
    regression = 'res://tests/run_all.gd'
    ammo = 'res://tests/qa_ammo_hand_compare_runner.gd'
    campaign = 'res://tests/qa_campaign_replay_runner.gd'
    simulator = 'res://tests/preart_simulator_probe.gd'
    visual = 'res://tests/qa_preart_visual_runner.gd'
    experience = 'res://tests/qa_autonomous_playtest_runner.gd'
}
$log = Join-Path $runtime 'stdout.log'
$err = Join-Path $runtime 'stderr.log'
$startedAt = [DateTime]::UtcNow
$arguments = @('--headless', '--path', ('"{0}"' -f $project), '--script', $scripts[$Mode])
if ($Mode -eq 'visual') {
    $arguments = @('--rendering-method', 'gl_compatibility', '--position', '-2000,-2000', '--path', ('"{0}"' -f $project), '--script', $scripts[$Mode])
}
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $log -RedirectStandardError $err
if (-not $process.WaitForExit(300000)) {
    Stop-Process -Id $process.Id -Force
    throw "QA stage timed out: $Mode"
}
$process.WaitForExit()
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath $err
Get-Content -Encoding UTF8 -LiteralPath $log | Select-Object -Last 8
if ($errors -match 'SCRIPT ERROR|Parse Error|Compile Error') { throw "Godot script failure: $errors" }
if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) { throw "Godot exit: $($process.ExitCode)" }
if ($Mode -eq 'regression') {
    if ((Get-Item -LiteralPath $env:QA_TEST_SUMMARY_PATH).LastWriteTimeUtc -lt $startedAt) { throw 'Regression summary is stale' }
    $summary = Get-Content -Raw -Encoding UTF8 -LiteralPath $env:QA_TEST_SUMMARY_PATH | ConvertFrom-Json
    if ($summary.failed -ne 0) { throw 'Regression failed' }
    $summary | ConvertTo-Json -Compress
}
if ($Mode -eq 'ammo') {
    python (Join-Path $PSScriptRoot 'analyze_ammo_hand.py') (Join-Path $env:QA_OUTPUT_DIR 'paired_encounters.json') `
        --output (Join-Path $runtime 'comparison.json') > (Join-Path $runtime 'comparison.stdout.log')
    if ($LASTEXITCODE -ne 0) { throw 'A/B comparison rejected incomplete or duplicate conditions' }
    $comparison = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'comparison.json') | ConvertFrom-Json
    [PSCustomObject]@{matched_pairs=$comparison.matched_pairs; decision=$comparison.decision; delta=$comparison.delta_B_minus_A} | ConvertTo-Json -Depth 5
}
Write-Output "QA artifacts: $runtime"
