param([switch]$Capture, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$workspace = Split-Path -Parent (Split-Path -Parent $repo)
$godot = Join-Path $workspace '.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$runtime = Join-Path $repo 'qa_runtime\art_sample\tower'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot 4.7 executable missing' }
if ($CheckOnly) { Write-Output "Sample: $project\redesign\samples\tower_battle.tscn"; exit 0 }
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x900')
if (-not $Capture) {
    $arguments += 'res://redesign/samples/tower_battle.tscn'
    # User-requested interactive sample window. All data remains isolated.
    Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $project
    exit 0
}
$arguments += @('--script', 'res://tests/tower_art_sample_runner.gd', '--position', '-2000,-2000')
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Id | Set-Content -LiteralPath (Join-Path $runtime 'process_id.txt')
if (-not $process.WaitForExit(60000)) { throw "Sample capture still running, PID $($process.Id). Inspect logs before restarting." }
$process.WaitForExit()
$output = Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
$errors = Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
Write-Output $output
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $output -match 'FAIL:|failures=[1-9]') { throw "Sample failed: $errors" }
if ($output -notmatch 'TOWER ART SAMPLE COMPLETE') { throw "Missing completion marker: $errors" }
Write-Output "Artifacts: $runtime"
