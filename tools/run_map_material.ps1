param([ValidateSet('current','legacy','preview')][string]$Mode='current')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/maps/pipe_material_'+$Mode+'_20261106')
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_ROUTE_REPORT=Join-Path $repo 'qa_runtime/campaign_magazine_20261101/integrated/rules/balance.json'
$env:QA_MAP_LEGACY_ONLY=if($Mode -eq 'legacy'){'1'}else{'0'}
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$script=switch($Mode){'preview'{'pipe_map_preview'} default{'map_material_ui'}}
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$proc=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--path',('"'+$project+'"'),'--script',('res://tests/'+$script+'.gd'),'--rendering-method','gl_compatibility','--position','-2000,-2000') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$proc.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(12)
while(-not $proc.WaitForExit(500)) {
    $errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
    if($errors -match 'SCRIPT ERROR|Parse Error|ERROR:' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
        throw "Map check interrupted: $errors"
    }
}
$proc.WaitForExit()
$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 8)
if($proc.ExitCode -ne 0 -or $result -match 'FAIL:|failures=[1-9]' -or $result -notmatch 'MAP .*COMPLETE.*failures=0'){throw "Map check failed: $runtime"}
Write-Output "Artifacts: $runtime"
