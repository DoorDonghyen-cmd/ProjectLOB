param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$qa = Join-Path $repo 'qa_runtime/shop_counter_review_20261104'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $qa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$position = '60,60'
Remove-Item Env:LOB_SHOP_COUNTER_CAPTURE -ErrorAction SilentlyContinue
if ($Capture) {
    $env:LOB_SHOP_COUNTER_CAPTURE = Join-Path $repo 'docs/qa/reports/shop_counter_review_2026-11-04'
    New-Item -ItemType Directory -Force -Path $env:LOB_SHOP_COUNTER_CAPTURE | Out-Null
    $position = '-2000,-2000'
}
$launch = @('--path', ('"' + $project + '"'), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800', '--position', $position, 'res://redesign/samples/shop_counter_review/preview.tscn')
$run = Start-Process -FilePath $engine -ArgumentList $launch -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qa 'stdout.log') -RedirectStandardError (Join-Path $qa 'stderr.log')
if ($Capture) {
    $null = $run.Handle
    if (-not $run.WaitForExit(55000)) {
        Stop-Process -Id $run.Id
        throw 'Shop counter preview capture timed out'
    }
    $run.WaitForExit()
    $report = Get-Content -Raw (Join-Path $qa 'stdout.log')
    Write-Output $report
    $errors = Get-Content -Raw (Join-Path $qa 'stderr.log')
    if ($run.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $report -notmatch 'SHOP COUNTER REVIEW checks=\d+ failures=0') {
        throw ('Godot preview failed. ' + $errors)
    }
}
