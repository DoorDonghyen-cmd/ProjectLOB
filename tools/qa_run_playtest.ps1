param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$RequestPath
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "qa_runtime"))
$statusPath = Join-Path $runtimeRoot "controller_status.json"
$projectPath = (Get-ChildItem -LiteralPath $repoRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "project.godot")
} | Select-Object -First 1).FullName
$dashboardRoot = Join-Path $repoRoot "docs\qa\dashboard"

function Write-ControllerStatus {
    param([hashtable]$Values)
    $current = @{}
    if (Test-Path -LiteralPath $statusPath) {
        try {
            $loaded = Get-Content -Raw -Encoding UTF8 -LiteralPath $statusPath | ConvertFrom-Json
            foreach ($property in $loaded.PSObject.Properties) { $current[$property.Name] = $property.Value }
        } catch { }
    }
    foreach ($key in $Values.Keys) { $current[$key] = $Values[$key] }
    $current["updated_at"] = [DateTime]::UtcNow.ToString("o")
    $tempPath = "$statusPath.tmp"
    $current | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 -LiteralPath $tempPath
    Move-Item -Force -LiteralPath $tempPath -Destination $statusPath
}

function Set-ProcessEnvironment {
    param([hashtable]$Variables)
    $previous = @{}
    foreach ($key in $Variables.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, [string]$Variables[$key], "Process")
    }
    return $previous
}

function Restore-ProcessEnvironment {
    param([hashtable]$Previous)
    foreach ($key in $Previous.Keys) {
        [Environment]::SetEnvironmentVariable($key, $Previous[$key], "Process")
    }
}

function Invoke-GodotStage {
    param(
        [string]$Name,
        [string]$Script,
        [string]$OutputDirectory,
        [int]$TimeoutSeconds,
        [hashtable]$Environment,
        [int[]]$AllowedExitCodes = @(0)
    )
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $stdoutPath = Join-Path $OutputDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $OutputDirectory "$Name.stderr.log"
    Write-ControllerStatus @{ state = "running"; stage = $Name; message = "$Name is running"; progress_detail = $Script }
    $previous = Set-ProcessEnvironment $Environment
    try {
        $arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", $Script)
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        Write-ControllerStatus @{ child_process_id = $process.Id }
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { Stop-Process -Id $process.Id -Force } catch { }
            throw "TIMEOUT:$Name exceeded ${TimeoutSeconds}s"
        }
        $process.WaitForExit()
        $process.Refresh()
        $stageExitCode = $process.ExitCode
        # Godot's Windows console wrapper can leave ExitCode unset even after the engine child exits.
        # Every stage has a mandatory artifact check, so an unset wrapper code is treated as 0 only
        # and never substitutes for artifact validation.
        if ($null -eq $stageExitCode -or [string]::IsNullOrWhiteSpace([string]$stageExitCode)) {
            $stageExitCode = 0
        }
        if ($AllowedExitCodes -notcontains $stageExitCode) {
            throw "EXIT:$Name returned $stageExitCode"
        }
        return @{
            exit_code = $stageExitCode
            stdout = $stdoutPath
            stderr = $stderrPath
        }
    } finally {
        Restore-ProcessEnvironment $previous
        Write-ControllerStatus @{ child_process_id = $null }
    }
}

try {
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
    $requestAbsolute = [System.IO.Path]::GetFullPath($RequestPath)
    if (-not $requestAbsolute.StartsWith($runtimeRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Request path is outside qa_runtime"
    }
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }
    if ([string]::IsNullOrWhiteSpace($projectPath) -or -not (Test-Path -LiteralPath (Join-Path $projectPath "project.godot"))) { throw "Godot project not found" }
    $request = Get-Content -Raw -Encoding UTF8 -LiteralPath $requestAbsolute | ConvertFrom-Json
    $seed = [Math]::Max(1, [int]$request.gameplay_seed)
    $targetEncounters = [Math]::Min(6, [Math]::Max(1, [int]$request.target_encounters))
    $sessionId = [string]$request.request_id
    if ($sessionId -notmatch '^qa-[0-9T-]+$') { throw "Invalid request_id" }
    $sessionRoot = Join-Path $runtimeRoot $sessionId
    $artifactRoot = Join-Path $sessionRoot "artifacts"
    $reportDir = Join-Path $artifactRoot "profile_reports"
    $teamDir = Join-Path $artifactRoot "team"
    $appDataRoot = Join-Path $sessionRoot "appdata"
    New-Item -ItemType Directory -Force -Path $reportDir, $teamDir, $appDataRoot | Out-Null

    $commit = (git -C $repoRoot rev-parse HEAD).Trim()
    $dirty = -not [string]::IsNullOrWhiteSpace((git -C $repoRoot status --porcelain))
    Write-ControllerStatus @{
        request_id = $sessionId
        state = "running"
        stage = "regression"
        message = "Starting regression in isolated APPDATA"
        started_at = [DateTime]::UtcNow.ToString("o")
        process_id = $PID
        child_process_id = $null
        progress = 5
        session_root = $sessionRoot
        error = $null
    }

    $commonEnvironment = @{
        "QA_COMMIT" = $commit
        "QA_GAMEPLAY_SEED" = $seed
        "QA_DIRTY_WORKTREE" = $dirty.ToString().ToLowerInvariant()
        "APPDATA" = (Join-Path $appDataRoot "Roaming")
        "LOCALAPPDATA" = (Join-Path $appDataRoot "Local")
        "GODOT_USER_HOME" = (Join-Path $appDataRoot "GodotHome")
    }
    New-Item -ItemType Directory -Force -Path $commonEnvironment.APPDATA, $commonEnvironment.LOCALAPPDATA, $commonEnvironment.GODOT_USER_HOME | Out-Null

    $regressionDir = Join-Path $artifactRoot "regression"
    $regressionSummaryPath = Join-Path $regressionDir "summary.json"
    $commonEnvironment["QA_TEST_SUMMARY_PATH"] = $regressionSummaryPath
    $regression = Invoke-GodotStage -Name "regression" -Script "res://tests/run_all.gd" `
        -OutputDirectory $regressionDir -TimeoutSeconds 300 -Environment $commonEnvironment
    if (-not (Test-Path -LiteralPath $regressionSummaryPath -PathType Leaf)) { throw "Structured regression summary missing" }
    $regressionSummary = Get-Content -Raw -Encoding UTF8 -LiteralPath $regressionSummaryPath | ConvertFrom-Json
    $regressionPassed = [int]$regressionSummary.passed
    $regressionFailed = [int]$regressionSummary.failed
    $regressionWarnings = [int]$regressionSummary.warnings
    Write-ControllerStatus @{ progress = 20; regression = @{ passed = $regressionPassed; failed = $regressionFailed; warnings = $regressionWarnings } }

    $coreFunDir = Join-Path $artifactRoot "core_fun"
    $coreFunPath = Join-Path $coreFunDir "core_fun_probe.json"
    $coreFunEnvironment = @{} + $commonEnvironment
    $coreFunEnvironment["QA_CORE_FUN_OUTPUT"] = $coreFunPath
    Invoke-GodotStage -Name "core_fun_probe" -Script "res://tests/qa_core_fun_probe_runner.gd" `
        -OutputDirectory $coreFunDir -TimeoutSeconds 60 -Environment $coreFunEnvironment | Out-Null
    if (-not (Test-Path -LiteralPath $coreFunPath -PathType Leaf)) { throw "core_fun_probe.json missing" }
    Write-ControllerStatus @{ progress = 25; stage = "core_fun_probe"; message = "Comparing identical ammo in planned and reversed orders" }

    $profiles = @("beginner", "aggressive", "conservative", "experimental")
    for ($index = 0; $index -lt $profiles.Count; $index++) {
        $profile = $profiles[$index]
        $profileDir = Join-Path $artifactRoot "profiles\$profile"
        $environment = @{} + $commonEnvironment
        $environment["QA_PROFILE"] = $profile
        $environment["QA_SESSION_ID"] = "$sessionId-$profile"
        $environment["QA_OUTPUT_DIR"] = $profileDir
        $environment["QA_REPORT_DIR"] = $reportDir
        $environment["QA_TARGET_ENCOUNTERS"] = $targetEncounters
        $environment["QA_CAPTURE"] = "false"
        Invoke-GodotStage -Name "profile_$profile" -Script "res://tests/qa_autonomous_playtest_runner.gd" `
            -OutputDirectory $profileDir -TimeoutSeconds 150 -Environment $environment | Out-Null
        $expectedReport = Join-Path $reportDir "$profile.json"
        if (-not (Test-Path -LiteralPath $expectedReport -PathType Leaf)) { throw "$profile report was not generated" }
        Write-ControllerStatus @{ progress = 25 + (($index + 1) * 11); profile = $profile; message = "$profile actual play completed" }
    }

    $compareDir = Join-Path $artifactRoot "comparison"
    $compareEnvironment = @{} + $commonEnvironment
    $compareEnvironment["QA_REPORT_DIR"] = $reportDir
    $compareEnvironment["QA_COMPARISON_OUTPUT"] = (Join-Path $compareDir "profile_comparison.json")
    Invoke-GodotStage -Name "profile_comparison" -Script "res://tests/qa_profile_compare_runner.gd" `
        -OutputDirectory $compareDir -TimeoutSeconds 60 -Environment $compareEnvironment | Out-Null
    if (-not (Test-Path -LiteralPath $compareEnvironment.QA_COMPARISON_OUTPUT -PathType Leaf)) { throw "profile_comparison.json missing" }
    Write-ControllerStatus @{ state = "integrating"; stage = "integration"; progress = 75; message = "Integrating fun signals and bug reproductions" }

    $finalEnvironment = @{} + $commonEnvironment
    $finalEnvironment["QA_SESSION_ID"] = $sessionId
    $finalEnvironment["QA_REPORT_DIR"] = $reportDir
    $finalEnvironment["QA_TEAM_OUTPUT_DIR"] = $teamDir
    $finalEnvironment["QA_REGRESSION_PASSED"] = $regressionPassed
    $finalEnvironment["QA_REGRESSION_FAILED"] = $regressionFailed
    $finalEnvironment["QA_REGRESSION_WARNINGS"] = $regressionWarnings
    $finalEnvironment["QA_REGRESSION_LOG"] = $regression.stdout
    $finalEnvironment["QA_CORE_FUN_PATH"] = $coreFunPath
    Invoke-GodotStage -Name "integration" -Script "res://tests/qa_playtest_finalize_runner.gd" `
        -OutputDirectory $teamDir -TimeoutSeconds 60 -Environment $finalEnvironment -AllowedExitCodes @(0, 1) | Out-Null

    $dashboardRunPath = Join-Path $teamDir "dashboard_run.json"
    if (-not (Test-Path -LiteralPath $dashboardRunPath -PathType Leaf)) { throw "dashboard_run.json missing" }
    $publishedRun = Join-Path $dashboardRoot "runs\$sessionId.json"
    Copy-Item -Force -LiteralPath $dashboardRunPath -Destination $publishedRun
    $historyEnvironment = @{} + $commonEnvironment
    $historyEnvironment["QA_DASHBOARD_RUNS_DIR"] = "res://../docs/qa/dashboard/runs"
    $historyEnvironment["QA_DASHBOARD_DATA_PATH"] = "res://../docs/qa/dashboard/dashboard_data.js"
    Invoke-GodotStage -Name "dashboard_history" -Script "res://tests/qa_dashboard_history_runner.gd" `
        -OutputDirectory (Join-Path $artifactRoot "dashboard") -TimeoutSeconds 60 -Environment $historyEnvironment | Out-Null

    $dashboardRun = Get-Content -Raw -Encoding UTF8 -LiteralPath $dashboardRunPath | ConvertFrom-Json
    Write-ControllerStatus @{
        state = "completed"
        stage = "complete"
        progress = 100
        message = "Actual-play fun and bug QA report generated"
        verdict = [string]$dashboardRun.status
        dashboard_run_path = $publishedRun
        completed_at = [DateTime]::UtcNow.ToString("o")
        process_id = $null
        child_process_id = $null
    }
} catch {
    $kind = if ($_.Exception.Message.StartsWith("TIMEOUT:")) { "timeout" } else { "infrastructure" }
    Write-ControllerStatus @{
        state = "failed"
        stage = $kind
        message = "QA run did not complete"
        error = $_.Exception.Message
        completed_at = [DateTime]::UtcNow.ToString("o")
        process_id = $null
        child_process_id = $null
    }
    exit 3
}
