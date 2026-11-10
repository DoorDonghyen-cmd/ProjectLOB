$ErrorActionPreference = 'Stop'
$repo='D:\ProjectLoB\worktrees\core-redesign'
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$qa = Join-Path $repo 'qa_runtime/shop_live/ammo_cohesion'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
$env:QA_OUTPUT_DIR = Join-Path $repo 'qa_runtime/shop_live/ammo_cohesion/output'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:QA_OUTPUT_DIR | Out-Null
$stdout = Join-Path $env:QA_OUTPUT_DIR 'stdout.log'
$stderr = Join-Path $env:QA_OUTPUT_DIR 'stderr.log'
$argsList = @('--path',('"{0}"' -f $project),'--script','res://tests/shop_live_runner.gd','--rendering-method','gl_compatibility','--resolution','1600x900','--position','-2000,-2000')
$p = Start-Process -FilePath 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe' -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $p.Handle
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while (-not $p.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $p.Id
        throw "Shop live checks interrupted: $errors"
    }
}
$p.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($p.ExitCode -ne 0 -or $errors -match 'ERROR:' -or $result -notmatch 'COMPLETE checks=\d+ failures=0') { throw "Shop live checks failed: $errors" }
