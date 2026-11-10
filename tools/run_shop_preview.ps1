param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$qa = Join-Path $repo 'qa_runtime/shop_preview'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
$env:QA_OUTPUT_DIR = $qa
New-Item -ItemType Directory -Force -Path $qa,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$argsList = @('--path',('"{0}"' -f $project),'--rendering-method','gl_compatibility','--resolution','1600x900')
if ($Capture) {
    $argsList += @('--script','res://tests/shop_preview_capture.gd','--position','-2000,-2000')
    $p = Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qa 'stdout.log') -RedirectStandardError (Join-Path $qa 'stderr.log')
    $null = $p.Handle
    $deadline = [DateTime]::UtcNow.AddMinutes(2)
    while (-not $p.WaitForExit(500)) {
        $errors = Get-Content -Raw -LiteralPath (Join-Path $qa 'stderr.log')
        if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
            Stop-Process -Id $p.Id
            throw "Shop preview capture failed: $errors"
        }
    }
    $p.WaitForExit()
    Get-Content -LiteralPath (Join-Path $qa 'stdout.log')
    Get-Content -LiteralPath (Join-Path $qa 'stderr.log')
    if ($p.ExitCode -ne 0) { throw 'Shop preview checks failed.' }
} else {
    $argsList += 'res://redesign/samples/shop_wireframe_preview.tscn'
    Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Normal -WorkingDirectory $project
}
