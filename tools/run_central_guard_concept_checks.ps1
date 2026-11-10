$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')} | Select-Object -First 1).FullName
$qa = Join-Path $repo 'qa_runtime\central_guard_concepts'
$env:APPDATA = Join-Path $qa 'Roaming'
$env:LOCALAPPDATA = Join-Path $qa 'Local'
$env:QA_OUTPUT_DIR = Join-Path $repo 'docs\qa\reports\assets\central_guard_variants_2026-10-25'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:QA_OUTPUT_DIR | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
foreach ($phase in @('import','capture')) {
    $stdout = Join-Path $env:QA_OUTPUT_DIR ($phase+'_stdout.log')
    $stderr = Join-Path $env:QA_OUTPUT_DIR ($phase+'_stderr.log')
    if ($phase -eq 'import') {
        $arguments = @('--headless','--path',('"{0}"' -f $project),'--editor','--import','--quit')
    } else {
        $arguments = @('--path',('"{0}"' -f $project),'--script','res://tests/central_guard_concepts_runner.gd','--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000')
    }
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    $deadline = [DateTime]::UtcNow.AddMinutes(3)
    while (-not $process.WaitForExit(500)) {
        $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
        if ($errors -match 'SCRIPT ERROR|Parse Error' -or [DateTime]::UtcNow -gt $deadline) {
            Stop-Process -Id $process.Id
            throw "Guard concept $phase interrupted: $errors"
        }
    }
    $process.WaitForExit()
    $result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($process.ExitCode -ne 0 -or $errors -match 'ERROR:' -or ($phase -eq 'capture' -and $result -notmatch 'COMPLETE checks=\d+ failures=0')) {
        throw "Guard concept $phase failed: $errors $result"
    }
    if ($phase -eq 'capture') { Write-Output $result }
}
Write-Output "Artifacts: $env:QA_OUTPUT_DIR"
