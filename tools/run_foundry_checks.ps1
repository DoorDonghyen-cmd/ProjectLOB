param(
    [ValidateSet('campaign','rules','ui','boss')][string]$Mode = 'campaign',
    [ValidateSet('baseline','current')][string]$Stage = 'current',
    [string]$Guns = 'burst,heavy,amplifier',
    [int]$SeedValue = 731042,
    [ValidatePattern('^[a-zA-Z0-9_-]*$')][string]$RunTag = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\foundry\${Mode}_${Stage}_${SeedValue}${RunTag}"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
$env:QA_GUNS = $Guns
$env:QA_SEED = "$SeedValue"
$env:QA_FOUNDRY_STAGE = $Stage
$env:QA_FOUNDRY_CAMPAIGN = Join-Path $repo "qa_runtime\foundry\campaign_current_$SeedValue"
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments = @('--path',('"{0}"' -f $project),'--script',"res://tests/foundry_${Mode}_runner.gd")
if ($Mode -ne 'ui') { $arguments += '--headless' } else { $arguments += @('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000') }
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(15)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Foundry QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
$actionErrors = $errors -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:\d+\)\r?\n?', ''
Write-Output $result
if ($actionErrors -match 'ERROR:|SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $result -notmatch 'FOUNDRY .* COMPLETE') { throw "Foundry QA failed: $errors" }
Write-Output "Artifacts: $runtime"
