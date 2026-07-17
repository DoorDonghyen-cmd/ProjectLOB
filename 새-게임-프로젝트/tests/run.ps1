# Last on Board - headless test runner (Windows)
# Usage:
#   .\tests\run.ps1
#   .\tests\run.ps1 -Godot "C:\path\Godot_v4.7-stable_win64_console.exe"
param([string]$Godot = $env:GODOT)

# UTF-8 output so Korean test logs render correctly in the console.
try { chcp 65001 > $null } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Find-Godot {
    $bases = @(
        "$env:USERPROFILE\OneDrive\Desktop",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Downloads",
        "$env:LOCALAPPDATA\Programs\Godot",
        "$env:LOCALAPPDATA\Godot",
        "$env:ProgramFiles\Godot",
        "${env:ProgramFiles(x86)}\Godot"
    )
    $all = @()
    foreach ($b in $bases) {
        if (Test-Path $b) {
            $all += Get-ChildItem -Path $b -Recurse -Depth 2 -Filter "Godot*4.7*.exe" -File -ErrorAction SilentlyContinue
        }
    }
    if (-not $all) { return $null }
    # Prefer the console build (its stdout shows in the terminal).
    $console = $all | Where-Object { $_.Name -like "*console*" } | Select-Object -First 1
    if ($console) { return $console.FullName }
    return ($all | Select-Object -First 1).FullName
}

if (-not $Godot) { $Godot = Find-Godot }

if (-not $Godot) {
    Write-Error "Godot 4.7 executable not found. Pass -Godot 'C:\path\Godot.exe' or set `$env:GODOT."
    exit 2
}

$proj = Split-Path -Parent $PSScriptRoot
Write-Host "Godot:   $Godot"
Write-Host "Project: $proj"
& $Godot --headless --path $proj --script res://tests/run_all.gd
exit $LASTEXITCODE
