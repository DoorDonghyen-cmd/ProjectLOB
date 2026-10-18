$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo 'qa_runtime\ammo_choice'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments = @('--headless','--path',('"{0}"' -f $project),'--script','res://tests/ammo_choice_audit.gd')
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(15)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Choice audit interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
Write-Output $result
if ($result -notmatch 'CHOICE AUDIT COMPLETE' -or $result -match 'failures=[1-9]' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0)) { throw 'Choice audit failed' }
Write-Output "Artifacts: $runtime"
