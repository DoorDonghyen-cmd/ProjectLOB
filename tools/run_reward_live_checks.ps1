$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo 'qa_runtime/reward_live_20261105'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = Join-Path $repo 'docs/qa/reports/reward_live_2026-11-05'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:QA_OUTPUT_DIR | Out-Null
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$arguments = @('--path', ('"{0}"' -f $project), '--script', 'res://tests/reward_live_runner.gd', '--rendering-method', 'gl_compatibility', '--resolution', '1280x800', '--position', '-2000,-2000')
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$run = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $run.Handle
$deadline = [DateTime]::UtcNow.AddSeconds(120)
while (-not $run.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $run.Id
        throw "Reward live checks interrupted: $errors"
    }
}
$run.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($run.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'REWARD LIVE COMPLETE checks=\d+ failures=0') {
    throw "Reward live checks failed: $errors"
}
