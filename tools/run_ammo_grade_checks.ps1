param([ValidateSet('rules','ui')][string]$Mode = 'rules')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\ammo_grade\$Mode"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
& $engine --headless --path $project --editor --import --quit 2>&1 | Out-File -LiteralPath (Join-Path $runtime 'import.log') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
$runner = "ammo_grade_${Mode}_runner"
$arguments = @('--path',('"{0}"' -f $project),'--script',"res://tests/$runner.gd")
if ($Mode -eq 'rules') { $arguments += '--headless' } else { $arguments += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }

$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Concept QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:' -or $result -notmatch 'AMMO GRADE (RULES|UI) COMPLETE checks=\d+ failures=0') { throw "Concept QA failed: $errors" }
Write-Output "Artifacts: $runtime"
