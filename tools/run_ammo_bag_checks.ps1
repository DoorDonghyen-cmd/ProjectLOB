param([ValidateSet('ui')][string]$Mode = 'ui')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\ammo_bag\$Mode"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$importOut = Join-Path $runtime 'import.log'
$importErr = Join-Path $runtime 'import_errors.log'
$importProcess = Start-Process -FilePath $engine -ArgumentList @('--headless','--path',('"{0}"' -f $project),'--editor','--import','--quit') -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $importOut -RedirectStandardError $importErr
if ($importProcess.ExitCode -ne 0 -or (Get-Content -Raw $importErr) -match 'SCRIPT ERROR|Parse Error') { throw "Godot import failed: $(Get-Content -Raw $importErr)" }
$runner = "ammo_bag_${Mode}_runner"
$arguments = @('--path',('"{0}"' -f $project),'--script',"res://tests/$runner.gd")
if ($Mode -ne 'ui') { $arguments += '--headless' } else { $arguments += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }

$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Ammo bag QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:' -or $result -notmatch 'AMMO BAG (RULES|UI) COMPLETE checks=\d+ failures=0') { throw "Ammo bag QA failed: $errors" }
Write-Output "Artifacts: $runtime"
