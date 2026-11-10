# Supply depot mockup (2026-11-07). Without -Capture: opens the review window (F1 stock, F2 full bag).
# With -Capture: runs the capture/verification pass into qa_runtime (never into docs).
# -Layout shelf (3rd draft, default) | column (2nd draft). F3 toggles inside the window.
param([switch]$Capture, [ValidateSet('shelf','column')][string]$Layout = 'shelf')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$qa = Join-Path $repo 'qa_runtime/supply_review_20261107'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scene = 'res://redesign/samples/supply_review/preview.tscn'
$env:LOB_SUPPLY_LAYOUT = $Layout
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800')
if (-not $Capture) {
    Remove-Item Env:LOB_SUPPLY_CAPTURE -ErrorAction SilentlyContinue
    Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','60,60',$scene))
    exit
}
$env:LOB_SUPPLY_CAPTURE = Join-Path $qa ('capture/' + $Layout)
New-Item -ItemType Directory -Force -Path $env:LOB_SUPPLY_CAPTURE | Out-Null
$stdout = Join-Path $qa 'stdout.log'
$stderr = Join-Path $qa 'stderr.log'
$run = Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','-2000,-2000',$scene)) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $run.Handle
$deadline = [DateTime]::UtcNow.AddSeconds(120)
while (-not $run.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) { Stop-Process -Id $run.Id; throw "Supply review interrupted: $errors" }
}
$run.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
Write-Output $result
if ($run.ExitCode -ne 0 -or $result -notmatch 'SUPPLY REVIEW COMPLETE checks=\d+ failures=0') { throw 'Supply review failed' }
