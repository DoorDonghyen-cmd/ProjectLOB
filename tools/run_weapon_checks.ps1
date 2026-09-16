param([ValidateSet('rules','ui')][string]$Mode = 'rules')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo "qa_runtime\weapons\$Mode"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot = (Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1).FullName
if (-not $godot) { throw 'Godot 4.7 executable not found.' }
$arguments = @('--path',$project,'--script',"res://tests/weapon_${Mode}_runner.gd")
if ($Mode -eq 'rules') { $arguments += '--headless' }
else { $arguments += @('--rendering-method','gl_compatibility','--position','-2000,-2000') }
$ErrorActionPreference = 'Continue'
& $godot @arguments 1> (Join-Path $runtime 'stdout.log') 2> (Join-Path $runtime 'stderr.log')
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$result = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stdout.log')
$errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $runtime 'stderr.log')
Write-Output $result
if ($exitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:') { throw "Weapon QA failed: $errors" }
Write-Output "Artifacts: $runtime"
