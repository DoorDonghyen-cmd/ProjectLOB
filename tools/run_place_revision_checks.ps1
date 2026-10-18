param([ValidateSet('rules','ui','combat','layout','clarity')][string]$Mode = 'rules')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo $(if ($Mode -eq 'clarity') {'qa_runtime\place_clarity'} elseif ($Mode -eq 'layout') {'qa_runtime\place_layout'} else {'qa_runtime\place_revision'})
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$runner = if ($Mode -eq 'clarity') {'place_clarity_ui_runner'} elseif ($Mode -eq 'layout') {'place_layout_ui_runner'} elseif ($Mode -eq 'ui') {'place_revision_ui_runner'} elseif ($Mode -eq 'combat') {'place_revision_combat_runner'} else {'place_revision_runner'}
$arguments = @('--path',('"{0}"' -f $project),'--script',"res://tests/$runner.gd")
if ($Mode -in @('ui','layout','clarity')) { $arguments += @('--rendering-method','gl_compatibility','--resolution','1280x800','--position','-2000,-2000') } else { $arguments += '--headless' }
$stdout = Join-Path $runtime "$Mode.log"
$stderr = Join-Path $runtime "$Mode.err"
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$deadline = [DateTime]::UtcNow.AddMinutes(5)
while (-not $process.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed|Lambda capture' -or [DateTime]::UtcNow -gt $deadline) {
        Stop-Process -Id $process.Id
        throw "Place QA interrupted: $errors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if ($errors -match 'SCRIPT ERROR|Parse Error|Assertion failed|Lambda capture' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*' -or ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $result -notmatch 'COMPLETE') { throw "Place QA failed: $errors" }
Write-Output "Artifacts: $runtime"
