param([string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
$build = Join-Path $repo 'builds\redesign-windows'
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
$exportPath = (Join-Path $build 'LastOnBoard-redesign.exe').Replace('\', '/')
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
start "" "%~dp0LastOnBoard-redesign.exe"
'@
    [IO.File]::WriteAllText((Join-Path $build 'Play-Redesign.cmd'), $launcher, [Text.Encoding]::ASCII)
    $readme = @'
Last on Board - 핵심 재설계 실험

Play-Redesign.cmd로 실행합니다. 이 폴더의 qa-profile에 자동 저장합니다.
기존 게임 및 다른 QA 실행의 세이브와 분리되어 있습니다.

마지막에 넣은 탄이 먼저 발사됩니다. 계획 중 취소는 무료입니다.
확정 뒤에는 사격 또는 시간을 쓰는 재장전으로 진행합니다.
단발: 피해 +1, 사격 1턴, 재장전 1턴.
일제: 전탄 사격 1턴, 재장전 3턴.
전술 패 5장, 다음 보충 2장 예고, 기본탄 매 장전 3발.
7개 교전 사이에 탄환/파츠/덱 정제를 선택합니다.
메뉴에서 규칙, 시드 지정, 이어 하기, 개발자 연습을 사용할 수 있습니다.
연습 모드에서는 일반 진행을 저장하지 않습니다.

아트 이전의 규칙/UX 검증용 프로토타입입니다.
자동 완주 경로는 사람의 재미나 전체 시드 승률을 보장하지 않습니다.

원본 비교 빌드: D:\ProjectLoB\builds\preart-windows\Play-Preart.cmd
브랜치: prototype/core-redesign
문서: docs/walkthrough_core_redesign_2026-09-11.md
재생성: tools/export_windows_redesign.ps1
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
