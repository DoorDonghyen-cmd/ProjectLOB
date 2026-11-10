param(
    [ValidateSet('rules','slice','continuation','probe','ui')][string]$Mode='rules',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Tag='current',
    [ValidatePattern('^(single|burst|scatter|heavy|amplifier)(,(single|burst|scatter|heavy|amplifier))*$')][string]$Guns='single,burst,scatter,heavy,amplifier',
    [ValidatePattern('^\d+(,\d+)*$')][string]$Seeds='731042',
    [ValidatePattern('^(scout|work|carrier|expedition)(,(scout|work|carrier|expedition))*$')][string]$Outfits='carrier',
    [ValidatePattern('^(11|12)(,(11|12))*$')][string]$Versions='11,12'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/combat_rhythm_20261030/'+$Tag)
$env:APPDATA=Join-Path $runtime 'Roaming'; $env:LOCALAPPDATA=Join-Path $runtime 'Local'; $env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns; $env:QA_SEEDS=$Seeds; $env:QA_OUTFITS=$Outfits; $env:QA_VERSIONS=$Versions; $env:QA_RHYTHM_MODE=$Mode
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$script=if ($Mode -eq 'ui') {'combat_rhythm_ui_runner.gd'} else {'combat_rhythm_runner.gd'}
$arguments=@('--path',('"{0}"' -f $project),'--script',('res://tests/'+$script))
if ($Mode -eq 'ui') {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')} else {$arguments+='--headless'}
$process=Start-Process -FilePath 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(20)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Rhythm QA interrupted: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stdout.log') -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath (Join-Path $runtime 'stderr.log') -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or $result -notmatch 'COMPLETE') {throw "Rhythm QA failed: $errors"}
