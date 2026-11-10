param(
    [ValidatePattern('^(single|burst|scatter|heavy|amplifier)(,(single|burst|scatter|heavy|amplifier))*$')][string]$Guns='single,burst,scatter,heavy,amplifier',
    [ValidatePattern('^\d+(,\d+)*$')][string]$Seeds='731042,17',
    [ValidateSet('scout','work','carrier','heatworker','hoist','recovery','expedition')][string]$Outfits='carrier',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Tag='current',
    [ValidateSet('elite','supply')][string]$Route='elite',
    [ValidateSet('first','fit','build','refit')][string]$Acquisition='refit',
    [ValidateRange(0,1)][int]$HeatRule=1,
    [ValidateSet('refit','bag','compress')][string]$Workshop='refit',
    [ValidateSet('campaign','probe','recovery')][string]$Mode='campaign',
    [string]$Source='',
    [string]$PathSource='',
    [ValidateSet('current_wide','preparation_options','without_afterburner','lens_for_afterburner','capacitor_for_afterburner')][string]$Preparation='current_wide'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/economy_20261029/'+$Tag)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns
$env:QA_SEEDS=$Seeds
$env:QA_OUTFITS=$Outfits
$env:QA_ROUTE=$Route
$env:QA_ACQUISITION=$Acquisition
$env:QA_HEAT_RULE=[string]$HeatRule
$env:QA_WORKSHOP=$Workshop
$env:QA_ECONOMY_SOURCE=$Source
$env:QA_PATH_SOURCE=$PathSource
$env:QA_PREPARATION=$Preparation
$env:QA_PROBE_MODES=''
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$runner=if ($Workshop -eq 'refit') {'economy_campaign_runner.gd'} else {'economy_workshop_runner.gd'}
if ($Mode -in @('probe','recovery')) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {throw 'A saved combat source is required.'}
    $runner='economy_'+$Mode+'_runner.gd'
    if ($Mode -eq 'recovery' -and -not (Test-Path -LiteralPath $PathSource -PathType Leaf)) {throw 'A validated diagnostic path is required.'}
}
$arguments=@('--headless','--path',('"{0}"' -f $project),'--script',('res://tests/'+$runner))
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
Set-Content -LiteralPath (Join-Path $runtime 'engine.pid') -Value $process.Id
$deadline=[DateTime]::UtcNow.AddMinutes(90)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Economy QA interrupted: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or $result -notmatch 'ECONOMY (CAMPAIGN|PROBE|RECOVERY) COMPLETE') {throw "Economy QA failed: $errors"}
