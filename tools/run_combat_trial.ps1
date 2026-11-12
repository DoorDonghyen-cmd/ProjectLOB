param([ValidateSet('wreckage','elite_shield')][string]$Scenario, [ValidateSet('play','rules','ui')][string]$Mode='play', [ValidateSet('weak','strict')][string]$Variant='weak')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$runtime = Join-Path $repo ("qa_runtime/${Scenario}_trial/" + $Mode)
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
$env:QA_SHIELD_VARIANT = $Variant
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine = 'D:/ProjectLoB/.tmp/godot-4.7/Godot_v4.7-stable_win64_console.exe'
$script = if ($Mode -eq 'play') { "res://redesign/samples/${Scenario}_trial.gd" } else { "res://tests/${Scenario}_$Mode.gd" }
$engineArguments = @('--path',('"'+$project+'"'),'--script',$script)
if ($Mode -eq 'rules') { $engineArguments += '--headless' } else { $engineArguments += @('--rendering-method','gl_compatibility','--resolution','1280x800') }
if ($Mode -eq 'play') { Start-Process -FilePath $engine -ArgumentList $engineArguments; exit }
if ($Mode -eq 'ui') { $engineArguments += @('--position','-2000,-2000') }
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$p = Start-Process -FilePath $engine -ArgumentList $engineArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $p.Handle
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while (-not $p.WaitForExit(500)) {
    $errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
    if ($errors -match 'ERROR:|Parse Error' -or [DateTime]::UtcNow -gt $deadline) { Stop-Process -Id $p.Id; throw "$Scenario QA interrupted: $errors" }
}
$p.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
Write-Output $result
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
$marker = $Scenario.ToUpperInvariant().Replace('_', ' ')
if ($p.ExitCode -ne 0 -or $errors -match 'ERROR:|Parse Error' -or $result -notmatch "$marker .*COMPLETE.*failures=0") { throw "$Scenario QA failed: $errors" }
