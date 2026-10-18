param([ValidateSet('rules','ui','chart','combat')][string]$Mode = 'rules', [string]$Label = 'current')
$ErrorActionPreference = 'Stop'
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid artifact label' }
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\maps\${Mode}_${Label}"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scripts = @{ rules='route_map_runner'; ui='route_map_ui_runner'; chart='route_map_chart_ui_runner'; combat='route_map_combat_runner' }
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments = @('--path',('"{0}"' -f $project),'--script',"res://tests/$($scripts[$Mode]).gd")
if ($Mode -in @('ui','chart')) { $arguments += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
else { $arguments += '--headless' }
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(15)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id -Force
        throw "Map check interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed|\bFAIL:' -or $result -match '\bFAIL:' -or $result -notmatch 'COMPLETE checks=\d+ failures=0') { throw "Map check failed: $errors" }
Write-Output "Artifacts: $runtime"
