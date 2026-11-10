param([ValidateSet('rules','ui')][string]$Mode='rules')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo 'qa_runtime/weapon_abilities_20261106'
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/weapon_abilities_'+$Mode+'.gd'))
if($Mode -eq 'rules'){$arguments+=@('--headless')}
else{$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')}
$stdout=Join-Path $runtime ($Mode+'_stdout.log');$stderr=Join-Path $runtime ($Mode+'_stderr.log')
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$p.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(8)
while(-not $p.WaitForExit(500)){
 $errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
 if($errors -match 'ERROR:|SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $p.Id;throw "Weapon ability check stopped: $errors"}
}
$p.WaitForExit()
$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
$errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or $errors -match 'ERROR:|SCRIPT ERROR|Parse Error' -or $result -notmatch 'COMPLETE.*failures=0'){throw "Weapon ability check failed: $runtime"}
