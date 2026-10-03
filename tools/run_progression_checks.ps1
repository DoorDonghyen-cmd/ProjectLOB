param(
    [ValidateSet('balance','rules','campaign')][string]$Mode = 'rules',
    [string]$Label = 'current'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid artifact label' }
$runtime = Join-Path $repo "qa_runtime\progression\${Mode}_${Label}"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scripts = @{ balance='build_diversity_audit'; rules='progression_rules_runner'; campaign='progression_campaign_runner' }
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments = @('--headless','--path',('"{0}"' -f $project),'--script',"res://tests/$($scripts[$Mode]).gd")
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Id | Set-Content -LiteralPath (Join-Path $runtime 'process_id.txt')
$deadline = [DateTime]::UtcNow.AddMinutes(12)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        throw "Progression QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed|\bFAIL:' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0)) { throw "Progression QA failed: $errors" }
if ($result -notmatch 'COMPLETE') { throw 'Missing completion marker' }
Write-Output "Artifacts: $runtime"
