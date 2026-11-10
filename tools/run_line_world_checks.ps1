param([ValidateSet('shop','map','capture')][string]$Mode='shop')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$family=if($Mode -eq 'shop'){'shop_live'}elseif($Mode -eq 'map'){'maps'}else{'line_theme_20261101'}
$runtime=Join-Path $repo ('qa_runtime/'+$family+'/line_theme_20261101/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:LOB_UI_DATA=Join-Path $repo 'docs/qa/reports/ui_prototype_2026-10-31/assets/game_data.json'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$script=switch($Mode){'shop'{'shop_live_runner'} 'map'{'line_world_ui'} 'capture'{'line_theme_capture'}}
$arguments=@('--path',('"'+$project+'"'),'--script',('res://tests/'+$script+'.gd'),'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(12)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Line world check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 6)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -match 'failures=[1-9]' -or $result -notmatch 'COMPLETE'){throw "Line world check failed: $errors"}
