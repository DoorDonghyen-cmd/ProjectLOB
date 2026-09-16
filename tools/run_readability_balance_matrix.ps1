param(
    [string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe',
    [string]$Seeds = '731042,17,90210',
    [switch]$ReuseFastRuns
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
if (-not $project) { throw 'Godot project not found.' }
$discoveredGodot = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1
if (-not (Test-Path -LiteralPath $GodotPath) -and $discoveredGodot) { $GodotPath = $discoveredGodot.FullName }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot 4.7 console executable not found.' }

$runtime = Join-Path $repo 'qa_runtime\readability\balance_matrix'
$env:APPDATA = Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA = Join-Path $runtime 'Local'
$env:QA_SEEDS = $Seeds
$env:QA_EXCHANGE = 'optional'
$env:QA_REQUIRE_SITUATIONAL = '0'
$env:QA_BEAM_WIDTH = '12'
$env:QA_SEARCH_DEPTH = '8'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null

$runs = @(
    @{ Name = 'ordinary_supply'; Course = 'false'; Policy = 'supply'; Basic = '0' },
    @{ Name = 'ordinary_lens'; Course = 'false'; Policy = 'lens'; Basic = '0' },
    @{ Name = 'ordinary_coil'; Course = 'false'; Policy = 'coil'; Basic = '0' },
    @{ Name = 'ordinary_loader'; Course = 'false'; Policy = 'loader'; Basic = '0' },
    @{ Name = 'ordinary_skip'; Course = 'false'; Policy = 'skip'; Basic = '0' },
    @{ Name = 'ordinary_remove'; Course = 'false'; Policy = 'remove'; Basic = '0' },
    @{ Name = 'course_supply'; Course = 'true'; Policy = 'supply'; Basic = '0' },
    @{ Name = 'ordinary_basic_only'; Course = 'false'; Policy = 'skip'; Basic = '1' }
)

$combined = @()
$summaries = @()
foreach ($run in $runs) {
    $outputDir = Join-Path $runtime $run.Name
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $env:QA_OUTPUT_DIR = $outputDir
    $env:QA_COURSE = $run.Course
    $env:QA_POLICY = $run.Policy
    $env:QA_BASIC_ONLY = $run.Basic
    $env:QA_GUN = ''
    $campaignPath = Join-Path $outputDir 'campaign_report.json'
    if (-not ($ReuseFastRuns -and (Test-Path -LiteralPath $campaignPath))) {
        $stdoutPath = Join-Path $outputDir 'stdout.log'
        $stderrPath = Join-Path $outputDir 'stderr.log'
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $GodotPath --headless --path $project --script 'res://tests/readability_campaign_runner.gd' 1> $stdoutPath 2> $stderrPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction
        $stdout = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutPath
        $stderr = Get-Content -Raw -Encoding UTF8 -LiteralPath $stderrPath
        Write-Output $stdout
        if ($exitCode -ne 0 -or $stderr -match 'SCRIPT ERROR|Parse Error|INTEGRITY FAIL|COMMAND REJECTED|Assertion failed' -or $stdout -notmatch 'READABILITY CAMPAIGN COMPLETE') {
            throw "Balance campaign failed: $($run.Name)`n$stderr"
        }
    }
    $payload = Get-Content -Raw -Encoding UTF8 -LiteralPath $campaignPath | ConvertFrom-Json
    $reports = @($payload.reports)
    $wins = @($reports | Where-Object { $_.won }).Count
    $ammoUsage = @{}
    foreach ($report in $reports) {
        $report | Add-Member -NotePropertyName matrix_run -NotePropertyValue $run.Name
        $combined += $report
        foreach ($property in $report.shots_by_ammo.PSObject.Properties) {
            if (-not $ammoUsage.ContainsKey($property.Name)) { $ammoUsage[$property.Name] = 0 }
            $ammoUsage[$property.Name] += [int]$property.Value
        }
    }
    $partUsage = @{}
    foreach ($group in ($reports | Group-Object final_part)) { $partUsage[$group.Name] = $group.Count }
    $summaries += [ordered]@{
        run = $run.Name
        course = [bool]::Parse($run.Course)
        policy = $run.Policy
        basic_only = $run.Basic -eq '1'
        reports = $reports.Count
        wins = $wins
        losses_or_search_limits = $reports.Count - $wins
        turns = [int](($reports | Measure-Object -Property turns -Sum).Sum)
        shots = [int](($reports | Measure-Object -Property shots -Sum).Sum)
        reloads = [int](($reports | Measure-Object -Property reloads -Sum).Sum)
        ammo_usage = $ammoUsage
        final_parts = $partUsage
    }
}

$deepProbes = @()
$deepFailures = @($combined | Where-Object { -not $_.won -and -not $_.basic_only })
foreach ($failure in $deepFailures) {
    $safeSeed = ([string]$failure.seed) -replace '[^0-9-]', '_'
    $selectedProbe = $null
    foreach ($probeWidth in @(5, 12, 50)) {
        $probeName = "deep_$($failure.matrix_run)_$($failure.gun)_${safeSeed}_w$probeWidth"
        $outputDir = Join-Path $runtime $probeName
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        $env:QA_OUTPUT_DIR = $outputDir
        $env:QA_SEEDS = [string]$failure.seed
        $env:QA_COURSE = ([bool]$failure.course).ToString().ToLowerInvariant()
        $env:QA_POLICY = [string]$failure.policy
        $env:QA_BASIC_ONLY = '0'
        $env:QA_GUN = [string]$failure.gun
        $env:QA_BEAM_WIDTH = [string]$probeWidth
        $env:QA_SEARCH_DEPTH = '12'
        $stdoutPath = Join-Path $outputDir 'stdout.log'
        $stderrPath = Join-Path $outputDir 'stderr.log'
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $GodotPath --headless --path $project --script 'res://tests/readability_campaign_runner.gd' 1> $stdoutPath 2> $stderrPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction
        $stdout = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutPath
        $stderr = Get-Content -Raw -Encoding UTF8 -LiteralPath $stderrPath
        Write-Output $stdout
        if ($exitCode -ne 0 -or $stderr -match 'SCRIPT ERROR|Parse Error|COMMAND REJECTED|Assertion failed' -or $stdout -notmatch 'READABILITY CAMPAIGN COMPLETE') {
            throw "Deep balance probe failed: $probeName`n$stderr"
        }
        $payload = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $outputDir 'campaign_report.json') | ConvertFrom-Json
        $selectedProbe = @($payload.reports)[0]
        $selectedProbe | Add-Member -NotePropertyName probe_beam_width -NotePropertyValue $probeWidth
        if ($selectedProbe.won) { break }
    }
    $selectedProbe | Add-Member -NotePropertyName matrix_source -NotePropertyValue $failure.matrix_run
    $deepProbes += $selectedProbe
}

$result = [ordered]@{
    generated_at = [DateTime]::UtcNow.ToString('o')
    method = 'bounded deterministic beam search; informational balance matrix, not human win rate'
    seeds = $Seeds.Split(',') | ForEach-Object { [int]$_ }
    summaries = $summaries
    deep_probes = $deepProbes
    unresolved_after_deep_probe = @($deepProbes | Where-Object { -not $_.won }).Count
    reports = $combined
}
$reportPath = Join-Path $runtime 'balance_matrix_report.json'
$result | ConvertTo-Json -Depth 100 | Set-Content -Encoding UTF8 -LiteralPath $reportPath
Write-Output "BALANCE MATRIX COMPLETE: $reportPath"
