param([string]$GodotPath = 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe', [ValidateSet('readability','city')][string]$BuildKind = 'city')
$ErrorActionPreference = 'Stop'
$discoveredGodot = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1
if (-not (Test-Path -LiteralPath $GodotPath) -and $discoveredGodot) { $GodotPath = $discoveredGodot.FullName }
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')
} | Select-Object -First 1).FullName
$build = Join-Path $repo "builds\${BuildKind}-windows"
$exeName = "LastOnBoard-$BuildKind.exe"
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
$exportPath = (Join-Path $build $exeName).Replace('\', '/')
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
    $arguments = @('--headless', '--path', $project, '--export-debug', 'Windows Redesign QA', $exportPath)
    $exportStdout = Join-Path $build 'export.stdout.log'
    $exportStderr = Join-Path $build 'export.stderr.log'
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $GodotPath @arguments 1> $exportStdout 2> $exportStderr
    $exportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($exportExitCode -ne 0) { throw 'Godot export exited with failure' }
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
        includes_working_tree = [bool](git -C $repo status --porcelain)
        game_loop = 'five regions; 35 floors; map/shop/events/progression; separate seven-combat training'
        weapons = @('single','burst','scatter','heavy','amplifier')
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
    $launcherName = if ($BuildKind -eq 'city') { 'Play-City.cmd' } else { 'Play-Readability.cmd' }
    $launcher = $launcher.Replace('LastOnBoard-readability.exe', $exeName)
    [IO.File]::WriteAllText((Join-Path $build $launcherName), $launcher, [Text.Encoding]::ASCII)
    $readme = @'
Last on Board - 전체 도시 등반 개편판

Play-City.cmd로 실행합니다. 이 폴더의 qa-profile에 자동 저장합니다.
기본 모드는 5계층 35층 도시 등반입니다. 맵 → 전투/무기고/보급/이벤트 → 계층 관문 → 정점.
'탄환 기초 훈련'을 켜면 별도의 7교전 학습 모드를 시작합니다.
맵에서 밝은 노드를 누르면 즉시 이동하고, 다른 방을 누르면 편성과 비용을 미리 봅니다.
환기구는 다음 전투 시작 거리를 2m 줄입니다. 상점과 이벤트를 지나도 유지하며 중첩하지 않습니다.
전투 보상: 탄환 2후보 / 효율 크레딧 / 보상 대신 정제 / 유지.
상점: 탄환 12Cr, 파츠 30Cr, 갱신 3Cr, 덱 정제 12Cr.
파츠 구매와 유료 정제는 방문당 각각 한 번이며 재접속·갱신 후에도 한도는 유지합니다.
무기는 등반 끝까지 유지하며 보행자/쇄도/산개/압쇄/증강 5종입니다. '특징·보급'에서 시작 덱을 확인합니다.
보행자: 전탄 연쇄, 모든 탄환 기본 주 피해 +1, 4칸/재장전 1턴.
쇄도: 전탄 연쇄, 같은 적 주 타격 3회마다 고정 추가 피해 4, 4칸/재장전 2턴.
산개: 전탄 연쇄, 매 탄환 생존 적 균등 무작위 표적, 5칸/재장전 2턴. 거리 확산은 없습니다.
압쇄: 전탄 연쇄, 화상 턴당 피해 2/전격 전이 피해 3, 4칸/재장전 1턴.
증강: 단발, 기본 피해·관통·효과 강도 2배, 3칸/재장전 1턴. 매 발 생존 적이 행동합니다.
증강의 연발 2타·화상 지속·증폭 다음 2발은 유지합니다. 충격과 탄창 공유 밀기 상한은 4m입니다.
연쇄 전체 후 생존 적은 한 번 행동합니다. 쇄도 적중 진도는 적별로 재장전 후에도 유지됩니다.
관문 탄창 성장 +2칸: 보행자/쇄도/압쇄 4→6, 산개 5→7, 증강 3→5. 파츠 교체 후에도 유지합니다.
기록실: 도시 기록20개, 전술 데이터, 시작 덱 성향 해금, 완주 후 난도0~10 해금.

카드: 이름 / 피해·관통 / 물리·화염·전기 속성 / 효과 하나. 2×2는 두 번 공격입니다.
화상은 적의 전진 직전에 피해를 주고 지속을 1 줄입니다. 기본 턴당1, 압쇄/증강은2피해입니다.
전격은 가장 가까운 다른 생존 적에게 고정 피해를 전이합니다. 기본2, 압쇄3, 증강4입니다.
명중·회피·균열·속성 저항은 없습니다.
카드를 누른 순서대로 발사합니다. 확정 전 칸 터치는 회수합니다.
'계산 보기'를 켜고 칸을 누르면 회수 없이 해당 발의 실제 피해 근거를 봅니다.
탄창 칸은 처치/남은 HP와 증폭·화상·밀기·전이·집중 추가 피해를 표시합니다.
산개는 미래 표적을 공개하지 않고 주 피해 범위와 최종 HP·처치·접촉 확률을 표시합니다.
확정 후에도 칸을 눌러 계산을 볼 수 있습니다. 기본 수치는 총기와 파츠를 반영합니다.
개발자 테스트의 '조합 결과 연습'에서 대표 조합 세 가지를 한 화면에서 시험할 수 있습니다.
개발자 테스트에는 맵·무기고·이벤트·보급·승강기·보상·정산 바로가기가 있습니다.
무기별 '같은 대열 조합 비교'와 무기 5종 선택 화면 바로가기도 제공합니다.
연습에서는 실제 도시 등반 저장을 변경하지 않습니다.
완주 화면은 런 전체 조합 성과와 탄환별 최종 장수를 요약합니다.

문서: docs/walkthrough_weapon_rules_2026-09-16.md
재생성: tools/export_windows_readability.ps1
기존 비교판: builds/chain-windows/Play-Chain.cmd
APK는 사용자 요청 전까지 제작하지 않습니다.
'@
    $readme = $readme.Replace('Play-City.cmd', $launcherName)
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
