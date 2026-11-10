param([ValidateSet('before','after')][string]$Stage='after',[switch]$Authored)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$runtime=Join-Path $repo ('qa_runtime/hud_material_20261106/'+$Stage)
if($Authored){$runtime=Join-Path $runtime 'authored'}
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR=$runtime
$env:QA_HUD_AUTHORED_ONLY=if($Authored){'1'}else{'0'}
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$stdout=Join-Path $runtime 'stdout.log';$stderr=Join-Path $runtime 'stderr.log'
$proc=Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList @('--path',('"'+$project+'"'),'--script','res://tests/hud_material_capture.gd','--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null=$proc.Handle
$deadline=[DateTime]::UtcNow.AddMinutes(10)
while(-not $proc.WaitForExit(500)) {
    $errors=Get-Content -LiteralPath $stderr -Raw -Encoding UTF8
    if($errors -match 'SCRIPT ERROR|Parse Error|ERROR:' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
        throw "Material capture interrupted: $errors"
    }
}
$proc.WaitForExit()
$result=Get-Content -LiteralPath $stdout -Raw -Encoding UTF8
Write-Output ($result -split "`n" | Select-Object -Last 5)
if($proc.ExitCode -ne 0 -or $result -notmatch 'HUD MATERIAL CAPTURE COMPLETE.*failures=0'){throw "Material capture failed: $runtime"}
Write-Output "Artifacts: $runtime"
