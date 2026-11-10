param([ValidateSet('rules','ui')][string]$Mode='rules')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/combat_ui_capacity_20261031/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"{0}"' -f $project),'--script',('res://tests/combat_ui_capacity_'+$Mode+'.gd'))
if ($Mode -eq 'rules') {$arguments+='--headless'} else {$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(3)
while (-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Capacity check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8;$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match 'failures=[1-9]' -or $result -notmatch 'COMPLETE') {throw "Capacity check failed: $errors"}
