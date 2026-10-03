param([string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
$build = Join-Path $repo 'builds\preart-windows'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$template = Join-Path $env:APPDATA 'Godot\export_templates\4.7.stable\windows_debug_x86_64.exe'
if (-not (Test-Path -LiteralPath $template)) { throw 'Install the matching Godot 4.7 export templates first.' }
$presetPath = Join-Path $project 'export_presets.cfg'
$hadPreset = Test-Path -LiteralPath $presetPath
$original = if ($hadPreset) { [IO.File]::ReadAllBytes($presetPath) } else { [byte[]]@() }
$existing = [Text.Encoding]::UTF8.GetString($original)
$indices = [regex]::Matches($existing, '\[preset\.(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }
$index = if ($indices) { ($indices | Measure-Object -Maximum).Maximum + 1 } else { 0 }
$templateForGodot = $template.Replace('\', '/')
$exportPath = (Join-Path $build 'LastOnBoard-preart.exe').Replace('\', '/')
$preset = @"

[preset.$index]
name="Windows Preart QA"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="assets/fonts/*OFL*.txt"
exclude_filter="tests/*"
export_path="$exportPath"
script_export_mode=2

[preset.$index.options]
custom_template/debug="$templateForGodot"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
codesign/enable=false
application/company_name=""
application/product_name="Last on Board - Pre-art QA"
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
    $arguments = @('--headless', '--path', ('"{0}"' -f $project), '--export-debug', '"Windows Preart QA"', ('"{0}"' -f $exportPath))
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
start "" "%~dp0LastOnBoard-preart.exe"
'@
    [IO.File]::WriteAllText((Join-Path $build 'Play-Preart.cmd'), $launcher, [Text.Encoding]::ASCII)
    $readme = @'
Last on Board - 아트 이전 검토 빌드

Play-Preart.cmd를 실행하면 이 폴더의 qa-profile에 진행도를 저장합니다.
기존 개발용 메타 저장 데이터와 분리해 처음부터 검토할 수 있습니다.

타이틀의 장전 안내 / 수집 기록 버튼에서 규칙과 모은 로어를 읽습니다.
장전 시 적 정보·탄환 후보·발사 순서를 함께 보는 전술 작업대가 열립니다.
최근 장전 취소는 무료이며 장전 확정 다음에 별도로 발사합니다.
전투 중 추가 장전은 작업대를 닫을 때 적의 전진 비용이 적용됩니다.
개발자 테스트에는 A/B 비교, 랜덤 패 체감, 탄환 카드 가독성,
관리/정점 적 편성 등 검토용 진입점이 있습니다.

기본 게임은 전체 전술탄 선택 A안입니다. 랜덤 공개 패 B안은 비교 기능이며
사람의 조합 성공감·피로·재도전 의사를 검증한 후 채택합니다.
현재 아트와 오디오는 최종 제작 완료 상태가 아닙니다.

재생성: tools/export_windows_preart.ps1
세부 검증: docs/walkthrough_preart_completion_2026-09-11.md
전술 작업대 개선: docs/walkthrough_tactical_workbench_2026-09-11.md
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
