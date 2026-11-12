param([string]$BackdropCandidate='')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo 'qa_runtime/equipment_live_20261106'
$runner = 'equipment_live_ui'
if ($BackdropCandidate) {
    $env:QA_BACKDROP_CANDIDATE = (Resolve-Path -LiteralPath $BackdropCandidate).Path
    $runtime = Join-Path $runtime 'backdrop'
    $runner = 'equipment_backdrop_ui'
}
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$arguments = @('--path',('"'+$project+'"'),'--script',"res://tests/$runner.gd",'--rendering-method','gl_compatibility','--position','-2000,-2000')
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $process.Handle
$deadline = [DateTime]::UtcNow.AddMinutes(8)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
    if ($errors -match 'ERROR:|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        throw "Equipment UI check interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
$errors = Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 10)
if ($process.ExitCode -ne 0 -or $errors -match 'ERROR:|Parse Error|Assertion failed' -or $result -match 'FAIL:' -or $result -notmatch 'EQUIPMENT (LIVE|BACKDROP) UI COMPLETE checks=\d+ failures=0') {
    throw "Equipment UI check failed: $errors"
}
Write-Output "Artifacts: $runtime"
