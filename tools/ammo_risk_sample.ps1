param([switch]$Capture, [switch]$Rules, [switch]$Feedback, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$workspace = Split-Path -Parent (Split-Path -Parent $repo)
$godot = Join-Path $workspace '.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$runtime = Join-Path $repo 'qa_runtime\ammo_risk\sample'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot 4.7 executable missing' }
if ($CheckOnly) { Write-Output "Sample: $project\redesign\samples\ammo_risk.tscn"; exit 0 }
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x900')
if (-not $Capture -and -not $Rules -and -not $Feedback) {
    $arguments += 'res://redesign/samples/ammo_risk.tscn'
    # This launcher explicitly opens the requested interactive game sample.
    Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $project
    exit 0
}
$runner = if ($Rules) { 'ammo_risk_rules_runner' } elseif ($Feedback) { 'ammo_risk_feedback_runner' } else { 'ammo_risk_ui_runner' }
$arguments += @('--script', "res://tests/$runner.gd")
if ($Rules) { $arguments += '--headless' } else { $arguments += @('--position', '-2000,-2000') }
$stdout = Join-Path $runtime "$runner.stdout.log"
$stderr = Join-Path $runtime "$runner.stderr.log"
$process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Id | Set-Content -LiteralPath (Join-Path $runtime "$runner.pid")
if (-not $process.WaitForExit(60000)) { throw "Sample check still running, PID $($process.Id). Inspect logs before restarting." }
$process.WaitForExit()
$output = Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
$errors = Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
Write-Output $output
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $output -match 'FAIL:|failures=[1-9]') { throw "Sample failed: $errors" }
$marker = if ($Rules) { 'AMMO RISK RULES COMPLETE' } elseif ($Feedback) { 'AMMO RISK FEEDBACK COMPLETE' } else { 'AMMO RISK UI COMPLETE' }
if ($output -notmatch $marker) { throw "Missing completion marker: $errors" }
Write-Output "Artifacts: $runtime"
