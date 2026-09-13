param([string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
$build = Join-Path $repo 'builds\readability-windows'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$template = Join-Path $env:APPDATA 'Godot\export_templates\4.7.stable\windows_debug_x86_64.exe'
if (-not (Test-Path -LiteralPath $template)) { throw 'Install the matching Godot 4.7 export templates first.' }
$presetPath = Join-Path $project 'export_presets.cfg'
$hadPreset = Test-Path -LiteralPath $presetPath
$original = if ($hadPreset) { [IO.File]::ReadAllBytes($presetPath) } else { [byte[]]@() }
$existing = if ($hadPreset) { [Text.Encoding]::UTF8.GetString($original) } else { '' }
$indices = [regex]::Matches($existing, '\[preset\.(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }
$index = if ($indices) { ($indices | Measure-Object -Maximum).Maximum + 1 } else { 0 }
$templateForGodot = $template.Replace('\', '/')
$exportPath = (Join-Path $build 'LastOnBoard-readability.exe').Replace('\', '/')
$preset = @"

[preset.$index]
name="Windows Redesign QA"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*"
export_path="$exportPath"
script_export_mode=2

[preset.$index.options]
custom_template/debug="$templateForGodot"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
application/company_name=""
application/product_name="Last on Board - Core Redesign"
"@
$temporaryContent = $existing + $preset
$utf8 = New-Object Text.UTF8Encoding($false)
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    [IO.File]::WriteAllText($presetPath, $temporaryContent, $utf8)
    $env:APPDATA = Join-Path $build 'qa-profile\Roaming'
    $env:LOCALAPPDATA = Join-Path $build 'qa-profile\Local'
    New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $arguments = @('--headless', '--path', ('"{0}"' -f $project), '--export-debug', '"Windows Redesign QA"', ('"{0}"' -f $exportPath))
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $build 'export.stdout.log') -RedirectStandardError (Join-Path $build 'export.stderr.log')
    if (-not $process.WaitForExit(300000)) { Stop-Process -Id $process.Id -Force; throw 'Export timed out' }
    $process.WaitForExit()
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) { throw 'Godot export exited with failure' }
    $errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $build 'export.stderr.log')
    if ($errors -match 'SCRIPT ERROR|Parse Error|Failed to export|Could not find export template') { throw $errors }
    if (-not (Test-Path -LiteralPath $exportPath)) { throw 'Exported executable missing' }
    $smoke = Start-Process -FilePath $exportPath -ArgumentList @('--headless', '--quit-after', '5') -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $build 'smoke.stdout.log') -RedirectStandardError (Join-Path $build 'smoke.stderr.log')
    if (-not $smoke.WaitForExit(30000)) { Stop-Process -Id $smoke.Id -Force; throw 'Exported executable smoke timed out' }
    $smoke.WaitForExit()
    $smokeErrors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $build 'smoke.stderr.log')
    if ($smokeErrors -match 'SCRIPT ERROR|Parse Error|Failed loading resource|Failed to load script') { throw $smokeErrors }
    if ($null -ne $smoke.ExitCode -and $smoke.ExitCode -ne 0) { throw 'Exported executable exited with failure' }
    Get-Item -LiteralPath $exportPath | Select-Object FullName, Length
    $hash = (Get-FileHash -LiteralPath $exportPath -Algorithm SHA256).Hash
    Write-Output "SHA256: $hash"
    $manifest = @{
        built_at = [DateTime]::UtcNow.ToString('o')
        source_commit = (git -C $repo rev-parse HEAD).Trim()
        includes_working_tree = $true
        sha256 = $hash
        smoke = 'headless startup passed'
        readiness = 'functional review; human gameplay acceptance pending'
    }
    $manifest | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'build_manifest.json')
    $launcher = @'
@echo off
setlocal
set "APPDATA=%~dp0qa-profile\Roaming"
set "LOCALAPPDATA=%~dp0qa-profile\Local"
start "" "%~dp0LastOnBoard-readability.exe"
'@
    [IO.File]::WriteAllText((Join-Path $build 'Play-Readability.cmd'), $launcher, [Text.Encoding]::ASCII)
    $readme = @'
Last on Board - 탄환 정보·단계 학습 개선판

Play-Readability.cmd로 실행합니다. 이 폴더의 qa-profile에 자동 저장합니다.
처음에는 '차근차근 배우기'가 선택됩니다. 끄면 기존 일반 런으로 시작합니다.
학습 순서: 강화 → 장갑/관통 → 연속 공격 → 명중/회피 → 다수 표적 → 복합 전투.
새 탄환은 해당 교전에서 자동 지급되며 첫 손패에 들어옵니다.

카드: 이름 / 위력·관통·명중 / 짧은 효과. 2×2는 두 번 공격입니다.
카드를 누른 순서대로 발사합니다. 확정 전 칸 터치는 회수합니다.
'계산 보기'를 켜고 칸을 누르면 회수 없이 해당 발의 실제 피해 근거를 봅니다.
확정 후에도 칸을 눌러 계산을 볼 수 있습니다. 기본 수치는 총기와 파츠를 반영합니다.
개발자 테스트에서 첫 강화·장갑·명중 교전을 바로 연습할 수 있습니다.

문서: docs/walkthrough_ammo_readability_2026-09-13.md
재생성: tools/export_windows_readability.ps1
기존 비교판: builds/chain-windows/Play-Chain.cmd
APK는 사용자 요청 전까지 제작하지 않습니다.
'@
    [IO.File]::WriteAllText((Join-Path $build 'README.txt'), $readme, $utf8)
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    # Restore the user's presets only if no other editor changed them during export.
    if ([IO.File]::ReadAllText($presetPath) -eq $temporaryContent) {
        if ($hadPreset) { [IO.File]::WriteAllBytes($presetPath, $original) }
        else { Remove-Item -LiteralPath $presetPath }
    } else {
        Write-Warning 'Export presets changed concurrently; preserved the newer file.'
    }
}
