param([ValidateSet('ui','flow','import','probe','visual','direct','restart','scroll','journey','readout','feedback')][string]$Mode='ui',[ValidateSet('write','read')][string]$Stage='write',[switch]$Fast,[ValidateSet('prototype_20261101','journey_flow_20261101','line_theme_20261101','journey_review_20261101','journey_feedback_20261101')][string]$Suite='prototype_20261101')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/combat_hud_20261031/'+$Suite+'/'+$Mode)
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_RESUME_PHASE=$Stage
$env:QA_FAST_HUD=if($Fast){'1'}else{'0'}
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$arguments=@('--path',('"'+$project+'"'))
if($Mode -eq 'import'){$arguments+=@('--headless','--editor','--import','--quit')}
else{
 $script=switch($Mode){'probe'{'res://tests/prototype_hud_probe.gd'} 'visual'{'res://tests/pixel_hud_visual.gd'} 'direct'{'res://tests/direct_ejection_ui.gd'} 'restart'{'res://tests/prototype_hud_restart.gd'} 'scroll'{'res://tests/prototype_hud_scroll.gd'} 'journey'{'res://tests/journey_flow_ui.gd'} 'readout'{'res://tests/journey_readout_ui.gd'} 'feedback'{'res://tests/journey_feedback_ui.gd'} default{'res://tests/combat_hud_'+$Mode+'.gd'}}
 $arguments+=@('--script',$script,'--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
}
$stdout=Join-Path $runtime 'stdout.log'
$stderr=Join-Path $runtime 'stderr.log'
if($Mode -eq 'restart'){$stdout=Join-Path $runtime ($Stage+'_stdout.log');$stderr=Join-Path $runtime ($Stage+'_stderr.log')}
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$process.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(12)
while(-not $process.WaitForExit(500)){
 $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
 if($errors -match 'ERROR:|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $process.Id;throw "Prototype HUD check stopped: $errors"}
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -match 'failures=[1-9]' -or ($Mode -ne 'import' -and $result -notmatch 'COMPLETE')){throw "Prototype HUD check failed: $errors"}
