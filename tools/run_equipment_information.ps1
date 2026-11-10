param([ValidateSet('before','after')][string]$Stage='after')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/equipment_information_20261106/'+$Stage)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$script=Join-Path $repo 'docs/qa/reports/equipment_information_2026-11-06/capture.gd'
$proc=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--path',('"'+$project+'"'),'--script',('"'+$script+'"'),'--rendering-method','gl_compatibility','--position','-2000,-2000') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$proc.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(5)
while(-not $proc.WaitForExit(500)) {
    $errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
    if($errors -match 'SCRIPT ERROR|Parse Error|ERROR:' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue;throw "Capture interrupted: $errors"}
}
$proc.WaitForExit();$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($proc.ExitCode -ne 0 -or $result -notmatch 'EQUIPMENT INFORMATION CAPTURE COMPLETE'){throw "Capture failed: $runtime"}
