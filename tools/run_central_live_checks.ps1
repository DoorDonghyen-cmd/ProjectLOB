param([ValidateSet('rules','ui','balance','probe','import')][string]$Mode='rules', [string]$Guns='single,burst,scatter,heavy,amplifier', [string]$Seeds='731042,17,931104', [string]$Tag='current', [ValidateSet('elite','supply')][string]$Route='elite', [ValidateSet('first','fit','build','refit')][string]$Acquisition='first', [ValidateRange(0,2)][int]$Revision=2)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/central_live/'+$Mode+'/'+$Tag)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_GUNS=$Guns
$env:QA_SEEDS=$Seeds
$env:QA_ROUTE=$Route
$env:QA_ACQUISITION=$Acquisition
$env:QA_COMBAT_REVISION=[string]$Revision
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments=@('--path',('"{0}"' -f $project))
if ($Mode -eq 'import') {$arguments+=@('--headless','--editor','--import','--quit')}
else {
    $arguments+=@('--script',"res://tests/central_live_${Mode}_runner.gd")
    if ($Mode -eq 'ui') {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')} else {$arguments+='--headless'}
}
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(90)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Central QA interrupted: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or ($Mode -ne 'import' -and $result -notmatch 'CENTRAL LIVE .* COMPLETE')) {throw "Central QA failed: $errors"}
