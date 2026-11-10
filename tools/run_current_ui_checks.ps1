param([string]$Only = '', [int]$Parallel = 4, [int]$CapSeconds = 900)
# Current UI check suites (2026-11-08). Runs every suite listed in docs/qa/ui-test-suites.md
# in its own isolated qa_runtime folder, stops a run that hangs after a script error, and
# fails if any suite reports a failure or a script error.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$engine = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$base = Join-Path $repo "qa_runtime\current_ui_checks\$stamp"
# Earned, save-valid states from the 2026-11-06 full climb (gate, entry, combat, shop, won).
$earned = Join-Path $repo 'qa_runtime\ammo_upgrade_single_20261106\balance_final'
if (-not (Test-Path -LiteralPath (Join-Path $earned 'won_single_17.json'))) { throw "Earned states missing: $earned (run tests/ammo_upgrade_live.gd first)" }
$env:QA_BUILD_DIR = $earned
$env:QA_GATE_DIR = $earned
$env:QA_GATE_PREFIX = 'gate_single_17'
$env:QA_LEGACY_GATE = Join-Path $repo 'qa_runtime\campaign_magazine_20261101\v3_single\rules\gate_single_731042_r1.json'
# name = folder the suite's isolation guard expects; '|plain' = output path without a trailing slash.
$suites = [ordered]@{
  'gate_live_ui' = 'gate_live'; 'supply_live_ui' = 'supply_live'; 'event_live_ui' = 'event_live'
  'build_live_ui' = 'build_live'; 'common_windows_ui' = 'common'; 'story_scenes_ui' = 'story_scenes'
  'equipment_live_ui' = 'equipment_live_20261106'; 'title_ui_runner' = 'title\ui'; 'preart_ux_runner' = 'preart'
  'equipment_dialog_ui' = 'equipment_dialog_20261106'; 'console_visual_runner' = 'console_visual'; 'modal_touch_runner' = 'modal_touch\ui'
  'line_world_ui' = 'maps'; 'shop_terminal_live_runner' = 'shop_terminal_live'; 'reward_live_runner' = 'reward_live_20261105'
  'results_live_runner' = 'results_live_20261104'; 'workshop_standard_ui' = 'ui_standard_20261104'
  'weapon_live_ui' = 'weapon_live_20261106\ui|plain'; 'build_engine_rules' = 'build_engine_rules'; 'build_engine_ui' = 'build_engine_ui'
}
$queue = [System.Collections.Queue]::new()
foreach ($name in $(if ($Only) { $Only.Split(',') } else { @($suites.Keys) })) { $queue.Enqueue($name) }
$running = @{}
$results = @()
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($queue.Count -gt 0 -and $running.Count -lt $Parallel) {
    $name = $queue.Dequeue()
    $spec = $suites[$name].Split('|')
    $rt = Join-Path $base "$name\qa_runtime\$($spec[0])"
    New-Item -ItemType Directory -Force -Path "$rt\Roaming", "$rt\Local" | Out-Null
    $env:APPDATA = "$rt\Roaming"; $env:LOCALAPPDATA = "$rt\Local"
    $env:QA_OUTPUT_DIR = $(if ($spec.Count -gt 1) { $rt } else { "$rt\" })
    $arguments = @('--path', ('"{0}"' -f $project), '--script', "res://tests/$name.gd", '--rendering-method', 'gl_compatibility', '--resolution', '1280x800', '--position', '-2000,-2000')
    $p = Start-Process -FilePath $engine -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput "$rt\stdout.log" -RedirectStandardError "$rt\stderr.log"
    $running[$name] = @{ p = $p; rt = $rt; start = Get-Date; size = -1; changed = Get-Date }
  }
  Start-Sleep -Seconds 3
  foreach ($name in @($running.Keys)) {
    $job = $running[$name]
    $state = $null
    if ($job.p.HasExited) { $state = 'done' }
    else {
      $size = (Get-Item "$($job.rt)\stdout.log").Length + (Get-Item "$($job.rt)\stderr.log").Length
      if ($size -ne $job.size) { $job.size = $size; $job.changed = Get-Date }
      $errored = Select-String -LiteralPath "$($job.rt)\stderr.log" -Pattern 'SCRIPT ERROR|Parse Error' -Quiet
      if ($errored -and ((Get-Date) - $job.changed).TotalSeconds -gt 20) { Stop-Process -Id $job.p.Id -Force; $state = 'hung after script error' }
      elseif (((Get-Date) - $job.start).TotalSeconds -gt $CapSeconds) { Stop-Process -Id $job.p.Id -Force; $state = 'timeout' }
    }
    if ($state) {
      $out = Get-Content -LiteralPath "$($job.rt)\stdout.log", "$($job.rt)\stderr.log" -Encoding UTF8
      $summary = ($out | Select-String 'checks=\d+' | Select-Object -Last 1).Line
      $fails = @($out | Select-String '^FAIL').Count
      $errors = @($out | Select-String 'SCRIPT ERROR|Parse Error').Count
      $ok = $state -eq 'done' -and $summary -match 'failures=0' -and $fails -eq 0 -and $errors -eq 0
      $results += [pscustomobject]@{ Suite = $name; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); State = $state; Summary = $summary; ScriptErrors = $errors; Folder = $job.rt }
      $running.Remove($name)
    }
  }
}
$results | Format-Table Suite, Result, State, Summary, ScriptErrors -AutoSize | Out-String -Width 220 | Write-Output
Write-Output "Artifacts: $base"
if (@($results | Where-Object Result -ne 'PASS').Count -gt 0) { throw 'Current UI checks failed.' }
