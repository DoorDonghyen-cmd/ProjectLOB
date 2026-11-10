param(
    [ValidateSet('rules','ui','campaign','recovery','probe')][string]$Mode='rules',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Tag='current',
    [ValidatePattern('^(single|burst|scatter|heavy|amplifier)(,(single|burst|scatter|heavy|amplifier))*$')][string]$Guns='single,burst,scatter,heavy,amplifier',
    [ValidatePattern('^\d+(,\d+)*$')][string]$Seeds='731042',
    [ValidateSet('scout','carrier','expedition')][string]$Outfit='carrier',
    [ValidateSet('refit','compress')][string]$Workshop='refit',
    [ValidateSet('growth','existing')][string]$Policy='growth',
    [string]$Source='', [string]$PathSource='',
    [ValidateSet('current_wide','preparation_options','without_afterburner')][string]$Preparation='preparation_options'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/late_growth_20261030/'+$Tag)
$env:APPDATA=Join-Path $runtime 'Roaming'; $env:LOCALAPPDATA=Join-Path $runtime 'Local'; $env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns; $env:QA_SEEDS=$Seeds; $env:QA_OUTFITS=$Outfit
$env:QA_WORKSHOP=$Workshop; $env:QA_GROWTH_POLICY=$Policy
$env:QA_ROUTE='elite'; $env:QA_ACQUISITION='refit'; $env:QA_HEAT_RULE='1'
$env:QA_ECONOMY_SOURCE=$Source; $env:QA_PATH_SOURCE=$PathSource; $env:QA_PREPARATION=$Preparation
$env:QA_PROBE_MODES=if ($Mode -eq 'probe') {$Preparation} else {''}
if ($Mode -eq 'probe' -and -not (Test-Path -LiteralPath $Source -PathType Leaf)) {throw 'Probe requires an earned combat checkpoint.'}
if ($Mode -eq 'recovery' -and (-not (Test-Path -LiteralPath $Source -PathType Leaf) -or -not (Test-Path -LiteralPath $PathSource -PathType Leaf))) {throw 'Recovery requires an earned combat checkpoint and candidate path report.'}
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"{0}"' -f $project),'--script',('res://tests/late_growth_'+$Mode+'_runner.gd'))
if ($Mode -eq 'ui') {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')} else {$arguments+='--headless'}
$process=Start-Process -FilePath 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(45)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Growth QA interrupted: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or $result -notmatch 'COMPLETE') {throw "Growth QA failed: $errors"}
