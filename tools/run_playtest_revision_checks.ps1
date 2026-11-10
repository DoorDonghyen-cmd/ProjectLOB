param([ValidateSet('performance','rules','ui','mobile_ui','mobile_save','render_ui','builds','combat','combat_ui','shop_ui','pressure','pressure_ui','pressure_probe','inventory','inventory_ui','emergency','emergency_ui','emergency_probe','payoff','payoff_ui','threat','threat_ui','sustained','sustained_ui','sustained_probe')][string]$Mode='performance', [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Tag='current', [ValidateRange(0,2)][int]$Revision=2)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/playtest_revision_20261026/'+$Mode+'/'+$Tag)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_REVISION_TAG=$Tag
$env:QA_COMBAT_REVISION=[string]$Revision
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$arguments=@('--path',('"{0}"' -f $project),'--script',"res://tests/playtest_revision_${Mode}_runner.gd")
if ($Mode.EndsWith('ui')) {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')} else {$arguments+='--headless'}
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(20)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Playtest revision QA interrupted: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or $result -notmatch 'PLAYTEST REVISION .* COMPLETE') {throw "Playtest revision QA failed: $errors"}
