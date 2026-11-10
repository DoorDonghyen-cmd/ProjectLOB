param([ValidateSet('catalog','integration','equipment','motion','outfits','preview')][string]$Suite='integration', [string]$OutputDirectory='')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runners=@{catalog='art_actor_catalog_runner';integration='unified_outfit_ui_runner';equipment='equipment_ui_runner';motion='actor_motion_ui_runner';outfits='outfits_live_runner';preview='outfit_preview_runner'}
$guards=@{catalog='outfits_unified_20261025';integration='outfits_unified_20261025';equipment='equipment';motion='actor_motion';outfits='outfits_live';preview='outfit_preview'}
$runtime=Join-Path $repo ('qa_runtime/'+$guards[$Suite]+'/unified')
$output=Join-Path $repo ('docs/qa/reports/assets/outfits_unified_2026-10-25/'+$Suite)
if ($OutputDirectory) { $output = [System.IO.Path]::GetFullPath((Join-Path $repo $OutputDirectory)) }
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$output
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$output | Out-Null
$stdout=Join-Path $output 'stdout.log'
$stderr=Join-Path $output 'stderr.log'
$argsList=@('--path',('"{0}"' -f $project),'--script',('res://tests/'+$runners[$Suite]+'.gd'),'--rendering-method','gl_compatibility','--resolution','1280x900','--position','-2000,-2000')
$process=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline=[DateTime]::UtcNow.AddMinutes(6)
while(-not $process.WaitForExit(500)) {
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Outfit QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
# Restricted Windows QA can deny the OS certificate store. This suite does no
# networking; keep the original stderr and ignore only that exact environment error.
$errors=$errors -replace '(?m)^ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?', ''
if(($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'ERROR:' -or $result -match 'FAIL:' -or $result -notmatch 'COMPLETE checks=\d+ failures=0') {throw "Outfit QA failed: $errors"}
Write-Output "Artifacts: $output"
