$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo 'qa_runtime\actor_motion'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments = @('--path',('"{0}"' -f $project),'--script','res://tests/actor_motion_ui_runner.gd','--rendering-method','gl_compatibility','--resolution','1280x900','--position','-2000,-2000')
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Actor motion QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $result -notmatch 'COMPLETE') { throw "Actor motion QA failed: $errors" }
Write-Output "Artifacts: $runtime"
