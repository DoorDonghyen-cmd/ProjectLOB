param(
    [ValidateSet('rules','probe','climb','ui')][string]$Mode='rules',
    [ValidateSet('single','burst','scatter','heavy','amplifier')][string]$Gun='single',
    [int]$Seed=17,
    [ValidateSet('carrier','scout')][string]$Outfit='carrier',
    [ValidateSet('safe','elite')][string]$Route='safe',
    [ValidateSet('','thermal_drive','inferno')][string]$Core='',
    [string]$Label='rules'
)
$ErrorActionPreference='Stop'
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid label' }
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime=Join-Path $repo "qa_runtime/leader_patterns_20261106/$Label"
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime;$env:QA_GUN=$Gun;$env:QA_SEED="$Seed";$env:QA_OUTFIT=$Outfit;$env:QA_ROUTE=$Route;$env:QA_CORE=$Core
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"{0}"' -f $project),'--script',"res://tests/leader_patterns_$Mode.gd")
if ($Mode -eq 'ui') { $arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000') } else { $arguments+='--headless' }
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(25)
while (-not $p.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if ($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline) { Stop-Process -Id $p.Id; throw "Leader patterns stopped: $errors" }
}
$p.WaitForExit()
$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 4)
if ($p.ExitCode -ne 0 -or $result -notmatch 'LEADER PATTERNS COMPLETE.*failures=0') { throw "Leader patterns failed: $runtime" }
