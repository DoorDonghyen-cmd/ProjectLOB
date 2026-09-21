param([ValidateSet('campaign','ui')][string]$Mode = 'campaign', [string]$Seed = '', [switch]$Hard, [ValidatePattern('^[a-z0-9_]*$')][string]$RunName = '', [string]$ReplaySource = '', [switch]$Refine, [switch]$LayoutOnly, [string]$UISource = '', [ValidatePattern('^(single|burst|scatter|heavy|amplifier)(,(single|burst|scatter|heavy|amplifier))*$')][string]$Weapons = 'single,burst')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtimeName = if ($RunName) { "${Mode}_$RunName" } else { $Mode }
$runtime = Join-Path $repo "qa_runtime\city\$runtimeName"
if ($LayoutOnly) { $runtime = Join-Path $runtime 'layout' }
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
$env:QA_CITY_SEED = $Seed
$env:QA_CITY_HARD = if ($Hard) { '1' } else { '0' }
$env:QA_CITY_REPLAY_SOURCE = if ($ReplaySource) { (Resolve-Path -LiteralPath $ReplaySource).Path } else { '' }
$env:QA_CITY_REFINE = if ($Refine) { '1' } else { '0' }
$env:QA_CITY_LAYOUT_ONLY = if ($LayoutOnly) { '1' } else { '0' }
$env:QA_CITY_SOURCE = if ($UISource) { (Resolve-Path -LiteralPath $UISource).Path } else { '' }
$env:QA_CITY_GUNS = $Weapons
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot = if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE)) { $env:GODOT_EXE } else { (Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1).FullName }
if (-not $godot) { throw 'Godot executable not found.' }
$arguments = @('--path',$project,'--script',"res://tests/city_${Mode}_runner.gd")
if ($Mode -eq 'campaign') { $arguments += '--headless' }
else { $arguments += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
$ErrorActionPreference = 'Continue'
& $godot @arguments 1> (Join-Path $runtime 'stdout.log') 2> (Join-Path $runtime 'stderr.log')
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$result = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stdout.log')
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stderr.log')
Write-Output $result
if ($exitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:') { throw "City QA failed: $errors" }
Write-Output "Artifacts: $runtime"
