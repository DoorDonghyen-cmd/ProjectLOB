param([switch]$Capture, [switch]$Classic, [switch]$Workstation)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$variant = if ($Classic) { 'gate_review_20261105' } elseif ($Workstation) { 'gate_workstation_20261105' } else { 'gate_threshold_20261105' }
$qa = Join-Path $repo "qa_runtime/$variant"
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800')
$sceneName = if ($Classic) { 'preview' } elseif ($Workstation) { 'workstation' } else { 'threshold_preview' }
$scene = "res://redesign/samples/gate_review/$sceneName.tscn"
if (-not $Capture) {
    Remove-Item Env:LOB_GATE_CAPTURE -ErrorAction SilentlyContinue
    Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','60,60',$scene))
    exit
}
$reportName = if ($Classic) { 'gate_review_2026-11-05' } elseif ($Workstation) { 'gate_workstation_2026-11-05' } else { 'gate_threshold_2026-11-05' }
$env:LOB_GATE_CAPTURE = Join-Path $repo "docs/qa/reports/$reportName"
New-Item -ItemType Directory -Force -Path $env:LOB_GATE_CAPTURE | Out-Null
$stdout = Join-Path $qa 'stdout.log'
$stderr = Join-Path $qa 'stderr.log'
$run = Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','-2000,-2000',$scene)) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $run.Handle
$deadline = [DateTime]::UtcNow.AddSeconds(60)
while (-not $run.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $run.Id
        throw "Gate review interrupted: $errors"
    }
}
$run.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($run.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'GATE REVIEW COMPLETE checks=\d+ failures=0') {
    throw "Gate review failed: $errors"
}

