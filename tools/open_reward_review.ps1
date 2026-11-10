param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$qa = Join-Path $repo 'qa_runtime/reward_review_20261104'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--resolution', '1280x800')
$scene = 'res://redesign/samples/reward_review/preview.tscn'
if (-not $Capture) {
    Remove-Item Env:LOB_REWARD_CAPTURE -ErrorAction SilentlyContinue
    Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','60,60',$scene))
    exit
}
$env:LOB_REWARD_CAPTURE = Join-Path $repo 'docs/qa/reports/reward_review_2026-11-04'
New-Item -ItemType Directory -Force -Path $env:LOB_REWARD_CAPTURE | Out-Null
$stdout = Join-Path $qa 'stdout.log'
$stderr = Join-Path $qa 'stderr.log'
$run = Start-Process -FilePath $engine -ArgumentList ($arguments + @('--position','-2000,-2000',$scene)) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $run.Handle
$deadline = [DateTime]::UtcNow.AddSeconds(60)
while (-not $run.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $run.Id
        throw "Reward review interrupted: $errors"
    }
}
$run.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($run.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'REWARD REVIEW COMPLETE checks=\d+ failures=0') {
    throw "Reward review failed: $errors"
}
