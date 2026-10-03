param(
    [ValidateSet('weapons','frontend','city','layout','production','pixel','navigation','interaction','feedback','progression')][string]$Mode = 'weapons',
    [switch]$FullCampaign,
    [string]$CampaignSource = '',
    [string]$Weapons = '',
    [string]$GodotPath = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$category = if ($Mode -eq 'city') { 'city\ui_director20261002' } else { "weapons\ui\director20261002_$Mode" }
$runtime = Join-Path $repo "qa_runtime\$category"
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_OUTPUT_DIR = $runtime
$env:QA_CITY_LAYOUT_ONLY = if ($FullCampaign) { '0' } else { '1' }
$env:QA_CITY_SOURCE = if ($CampaignSource) { (Resolve-Path -LiteralPath $CampaignSource).Path } else { Join-Path $repo 'docs\qa\reports\progression_2026-10-03_assets\city_campaign_report.json' }
$env:QA_CITY_UI_GUNS = $Weapons
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$scripts = @{ weapons = 'weapon_ui_runner'; frontend = 'frontend_ui_runner'; city = 'city_ui_runner'; layout = 'director_layout_runner'; production = 'production_experience_runner'; pixel = 'pixel_battle_runner'; navigation = 'navigation_ui_runner'; interaction = 'interaction_flow_runner' }
$scripts.feedback = 'build_feedback_runner'
$scripts.progression = 'progression_ui_runner'
$arguments = @('--path', ('"{0}"' -f $project), '--script', "res://tests/$($scripts[$Mode]).gd", '--rendering-method', 'gl_compatibility', '--position', '-2000,-2000')
$stdout = Join-Path $runtime 'stdout.log'
$stderr = Join-Path $runtime 'stderr.log'
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Id | Set-Content -LiteralPath (Join-Path $runtime 'process_id.txt')
$deadline = [DateTime]::UtcNow.AddSeconds($(if ($FullCampaign) { 900 } else { 300 }))
while (-not $process.WaitForExit(500)) {
    $liveErrors = if (Test-Path -LiteralPath $stderr) { Get-Content -Raw -LiteralPath $stderr -Encoding UTF8 } else { '' }
    if ($liveErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or [DateTime]::UtcNow -gt $deadline) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        throw "UI check interrupted: $Mode. $liveErrors"
    }
}
$process.WaitForExit()
$result = Get-Content -Raw -LiteralPath $stdout -Encoding UTF8
$errors = Get-Content -Raw -LiteralPath $stderr -Encoding UTF8
Write-Output $result
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed|\bFAIL:' -or $result -match '\bFAIL:|\bfailures=[1-9]\d*') { throw "UI check failed: $errors" }
$completion = @{ weapons = 'WEAPON UI COMPLETE'; frontend = 'FRONTEND UI CHECKS'; city = 'CITY UI COMPLETE'; layout = 'DIRECTOR LAYOUT COMPLETE'; production = 'PRODUCTION EXPERIENCE COMPLETE'; pixel = 'PIXEL BATTLE COMPLETE'; navigation = 'NAVIGATION UI COMPLETE'; interaction = 'INTERACTION FLOW COMPLETE' }
$completion.feedback = 'BUILD FEEDBACK COMPLETE'
$completion.progression = 'PROGRESSION UI COMPLETE'
if (-not $result.Contains($completion[$Mode])) { throw 'UI check completion marker missing' }
Write-Output "Artifacts: $runtime"
