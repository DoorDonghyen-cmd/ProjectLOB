param([ValidateSet('capture','ui','flow','visual','import')][string]$Mode='ui')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/combat_hud_20261031/pixel_20261101/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'))
if($Mode -eq 'import'){$arguments+=@('--headless','--editor','--import','--quit')}
else{
 $script=if($Mode -in @('ui','flow')){'res://tests/combat_hud_'+$Mode+'.gd'}else{'res://tests/pixel_hud_'+$Mode+'.gd'}
 $arguments+=@('--script',$script,'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
}
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(12)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Pixel HUD check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8;$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -match 'failures=[1-9]' -or ($Mode -ne 'import' -and $result -notmatch 'COMPLETE')){throw "Pixel HUD check failed: $errors"}
