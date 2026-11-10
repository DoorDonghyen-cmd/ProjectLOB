# Event (조우) mockup (2026-11-08). Without -Capture: opens the review window (F1 door, F2 sealed crate, F3 cart, F4 ambush seed).
# With -Capture: runs the capture/verification pass into qa_runtime (never into docs).
param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$qa = Join-Path $repo 'qa_runtime/event_review_20261108'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scene = 'res://redesign/samples/event_review/preview.tscn'
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800')
if (-not $Capture) {
    Remove-Item Env:LOB_EVENT_CAPTURE -ErrorAction SilentlyContinue
    Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','60,60',$scene))
    exit
}
$env:LOB_EVENT_CAPTURE = Join-Path $qa 'capture'
New-Item -ItemType Directory -Force -Path $env:LOB_EVENT_CAPTURE | Out-Null
$stdout = Join-Path $qa 'stdout.log'
$stderr = Join-Path $qa 'stderr.log'
$run = Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','-2000,-2000',$scene)) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $run.Handle
$deadline = [DateTime]::UtcNow.AddSeconds(120)
while (-not $run.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) { Stop-Process -Id $run.Id; throw "Event review interrupted: $errors" }
}
$run.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
Write-Output $result
if ($run.ExitCode -ne 0 -or $result -notmatch 'EVENT REVIEW COMPLETE checks=\d+ failures=0') { throw 'Event review failed' }
