param([switch]$Capture, [switch]$Console)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$variant = if ($Console) { 'shop_console_crt_20261104' } else { 'shop_terminal_data_deck_20261104' }
$scene = if ($Console) { 'console_preview.tscn' } else { 'preview.tscn' }
$qa = Join-Path $repo "qa_runtime/$variant"
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $qa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$position = '60,60'
Remove-Item Env:LOB_SHOP_COUNTER_CAPTURE -ErrorAction SilentlyContinue
Remove-Item Env:LOB_SHOP_TERMINAL_CAPTURE -ErrorAction SilentlyContinue
if ($Capture) {
    $env:LOB_SHOP_TERMINAL_CAPTURE = Join-Path $qa 'captures'
    New-Item -ItemType Directory -Force -Path $env:LOB_SHOP_TERMINAL_CAPTURE | Out-Null
    $position = '-2000,-2000'
}
$launch = @('--path', ('"' + $project + '"'), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800', '--position', $position, "res://redesign/samples/shop_terminal_review/$scene")
$run = Start-Process -FilePath $engine -ArgumentList $launch -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qa 'stdout.log') -RedirectStandardError (Join-Path $qa 'stderr.log')
if ($Capture) {
    $null = $run.Handle
    if (-not $run.WaitForExit(55000)) {
        Stop-Process -Id $run.Id
        throw 'Shop terminal preview capture timed out'
    }
    $run.WaitForExit()
    $report = Get-Content -Raw (Join-Path $qa 'stdout.log')
    Write-Output $report
    $errors = Get-Content -Raw (Join-Path $qa 'stderr.log')
    if ($run.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $report -notmatch 'SHOP TERMINAL RECORD checks=\d+ failures=0' -or $report -notmatch 'SHOP COUNTER REVIEW checks=\d+ failures=0') {
        throw ('Godot preview failed. ' + $errors)
    }
}
