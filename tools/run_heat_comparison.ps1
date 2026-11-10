param([ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Tag='current')
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
& python (Join-Path $PSScriptRoot 'heat_comparison/prepare.py') $Tag
if ($LASTEXITCODE -ne 0) {throw 'Heat experiment preparation failed'}
$runtime=Join-Path $repo ('qa_runtime/heat_comparison/'+$Tag)
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
foreach ($variant in @('original','experiment')) {
    $project=Join-Path $runtime $variant
    $env:APPDATA=Join-Path $project 'Roaming'
    $env:LOCALAPPDATA=Join-Path $project 'Local'
    $env:QA_OUTPUT_DIR=$project
    $env:QA_ORIGINAL=if ($variant -eq 'original') {'1'} else {'0'}
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $stdout=Join-Path $project 'stdout.log'
    $stderr=Join-Path $project 'stderr.log'
    $arguments=@('--headless','--path',('"{0}"' -f $project),'--script','res://runner.gd')
    $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null=$process.Handle
    Set-Content -LiteralPath (Join-Path $project 'process_id.txt') -Value $process.Id
    $deadline=[DateTime]::UtcNow.AddMinutes(12)
    while (-not $process.WaitForExit(500)) {
        $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
        $progress=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
        if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $progress -match 'FAIL:' -or [DateTime]::UtcNow -gt $deadline) {Stop-Process -Id $process.Id;throw "Heat comparison interrupted: $errors $progress"}
    }
    $process.WaitForExit()
    $result=Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
    $errors=Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    Write-Output $result
    if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -match 'FAIL:|failures=[1-9]' -or $result -notmatch 'HEAT COMPARISON COMPLETE') {throw "Heat comparison failed: $errors"}
}
