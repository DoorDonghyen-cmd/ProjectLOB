param([ValidateSet('before','after')][string]$Stage='after')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/equipment_dialog_20261106/'+$Stage)
$env:APPDATA=Join-Path $runtime 'Roaming';$env:LOCALAPPDATA=Join-Path $runtime 'Local';$env:QA_OUTPUT_DIR=$runtime
$env:QA_DIALOG_AUTHORED=if($Stage -eq 'after'){'1'}else{'0'}
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$p=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--path',('"'+$project+'"'),'--script','res://tests/equipment_dialog_ui.gd','--rendering-method','gl_compatibility','--position','-2000,-2000') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$p.Handle;$deadline=[DateTime]::UtcNow.AddMinutes(6)
while(-not $p.WaitForExit(500)) {
    $errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
    if($errors -match 'SCRIPT ERROR|Parse Error|ERROR:' -or [DateTime]::UtcNow -gt $deadline){Stop-Process -Id $p.Id -ErrorAction SilentlyContinue;throw "Dialog check interrupted: $errors"}
}
$p.WaitForExit();$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($p.ExitCode -ne 0 -or $result -notmatch 'EQUIPMENT DIALOG COMPLETE.*failures=0'){throw "Dialog check failed: $runtime"}
