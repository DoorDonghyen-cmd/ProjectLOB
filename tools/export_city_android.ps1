param(
    [string]$GodotPath = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe',
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaSdk = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot',
    [string]$BuildToolsVersion = '36.1.0',
    [ValidateSet('universal', 'arm64')][string]$Architecture = 'universal',
    [ValidateSet('campaign', 'weapon-magazine', 'magazine-journey')][string]$PlayMode = 'campaign',
    [int]$VersionCode = [int](Get-Date -Format 'yyyyMMdd'),
    [string]$VersionName = ('0.5.' + (Get-Date -Format 'yyyyMMdd.HHmmss')),
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath)) {
    $GodotPath = (Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'OneDrive\Desktop') -Filter 'Godot_v4.7-stable_win64_console.exe' -File -Recurse | Select-Object -First 1).FullName
}
$repo = Split-Path -Parent $PSScriptRoot
$project = (Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$build = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $repo 'builds\city-android' }
$apk = Join-Path $build 'LastOnBoard-city.apk'
$templates = Join-Path $env:APPDATA 'Godot\export_templates\4.7.stable'
$debugKey = Join-Path $env:APPDATA 'Godot\keystores\debug.keystore'
$buildTools = Join-Path $AndroidSdk "build-tools\$BuildToolsVersion"
foreach ($required in @($GodotPath, "$templates\android_debug.apk", "$templates\android_release.apk", $debugKey, "$JavaSdk\bin\java.exe", "$buildTools\apksigner.bat", "$buildTools\zipalign.exe", "$buildTools\aapt.exe")) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build prerequisite: $required" }
}
New-Item -ItemType Directory -Force -Path $build | Out-Null
$presetPath = Join-Path $project 'export_presets.cfg'
$hadPreset = Test-Path -LiteralPath $presetPath
$original = if ($hadPreset) { [IO.File]::ReadAllBytes($presetPath) } else { [byte[]]@() }
$projectSettingsPath = Join-Path $project 'project.godot'
$originalProjectSettings = [IO.File]::ReadAllBytes($projectSettingsPath)
$projectSettingsText = [Text.Encoding]::UTF8.GetString($originalProjectSettings)
$playModes = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'mobile_play_modes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$modeSpec = $playModes.$PlayMode
if (-not $modeSpec) { throw 'Unsupported mobile play mode.' }
$mainScene = $modeSpec.main_scene
if (-not (Test-Path -LiteralPath (Join-Path $project $mainScene.Substring(6)))) { throw 'Requested entry scene is missing.' }
if ([regex]::Matches($projectSettingsText, '(?m)^run/main_scene="[^"]*"').Count -ne 1) { throw 'Expected one main scene setting.' }
$temporaryProjectSettings = [regex]::Replace($projectSettingsText, '(?m)^run/main_scene="[^"]*"', ('run/main_scene="' + $mainScene + '"'))
$existing = if ($hadPreset) { [Text.Encoding]::UTF8.GetString($original) } else { '' }
$indices = [regex]::Matches($existing, '\[preset\.(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }
$index = if ($indices) { ($indices | Measure-Object -Maximum).Maximum + 1 } else { 0 }
$templateRoot = $templates.Replace('\', '/')
$exportPath = $apk.Replace('\', '/')
$presetName = "Android City Test $VersionCode"
# Keep retired source art on disk; exclude only the reviewed, explicit paths.
$exclusions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'mobile_export_exclusions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$excludeFilter = (@('tests/*') + @($exclusions.files)) -join ','
$includeFilter = 'assets/fonts/*OFL*.txt'
if ($PlayMode -eq 'weapon-magazine') { $includeFilter += ',redesign/samples/combat_weapon_*.json' }
$exportFilter = 'all_resources'
$exportFilesLine = ''
$comparisonResources = @()
if ($PlayMode -ne 'campaign') {
    $resourceList = Join-Path $build 'comparison_resources.json'
    & python (Join-Path $PSScriptRoot 'mobile_comparison_resources.py') --project $project --play-mode $PlayMode --output $resourceList
    if ($LASTEXITCODE -ne 0) { throw 'Comparison dependency selection failed.' }
    $comparisonResources = Get-Content -Raw -Encoding UTF8 -LiteralPath $resourceList | ConvertFrom-Json
    if ($comparisonResources.Count -lt 2 -or $comparisonResources[0] -isnot [string]) { throw 'Expected a flat comparison resource list.' }
    $exportFilter = 'resources'
    $exportFilesLine = 'export_files=PackedStringArray(' + (($comparisonResources | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ')'
}
$armv7Enabled = if ($Architecture -eq 'universal') { 'true' } else { 'false' }
$abis = if ($Architecture -eq 'universal') { @('arm64-v8a', 'armeabi-v7a') } else { @('arm64-v8a') }
$preset = @"

[preset.$index]
name="$presetName"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="$exportFilter"
$exportFilesLine
include_filter="$includeFilter"
exclude_filter="$excludeFilter"
export_path="$exportPath"
script_export_mode=2

[preset.$index.options]
custom_template/debug="$templateRoot/android_debug.apk"
custom_template/release="$templateRoot/android_release.apk"
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=$armv7Enabled
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=$VersionCode
version/name="$VersionName"
package/unique_name="com.lastonboard.prototype"
package/name="Last on Board Test"
package/signed=true
package/retain_data_on_uninstall=false
screen/immersive_mode=true
screen/edge_to_edge=false
permissions/internet=false
permissions/access_network_state=false
permissions/read_external_storage=false
permissions/write_external_storage=false
"@
$sourceCommit = (git -C $repo rev-parse HEAD).Trim()
$sourceDirty = [bool](git -C $repo status --porcelain)
$temporaryContent = $existing + $preset
$utf8 = New-Object Text.UTF8Encoding($false)
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousJavaHome = $env:JAVA_HOME
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:APPDATA = Join-Path $build 'qa-profile\Roaming'
    $env:LOCALAPPDATA = Join-Path $build 'qa-profile\Local'
    $env:JAVA_HOME = $JavaSdk
    $env:TEMP = Join-Path $build 'qa-profile\Temp'
    $env:TMP = $env:TEMP
    $settingsRoot = Join-Path $env:APPDATA 'Godot'
    New-Item -ItemType Directory -Force -Path $settingsRoot,$env:LOCALAPPDATA,$env:TEMP | Out-Null
    $settings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
interface/editor/localization/editor_language="en"
export/android/java_sdk_path="$($JavaSdk.Replace('\', '/'))"
export/android/android_sdk_path="$($AndroidSdk.Replace('\', '/'))"
export/android/debug_keystore="$($debugKey.Replace('\', '/'))"
export/android/debug_keystore_user="androiddebugkey"
export/android/debug_keystore_pass="android"
"@
    # Android's standard local debug certificate; never a release signing key.
    [IO.File]::WriteAllText((Join-Path $settingsRoot 'editor_settings-4.7.tres'), $settings, $utf8)
    [IO.File]::WriteAllText($presetPath, $temporaryContent, $utf8)
    [IO.File]::WriteAllText($projectSettingsPath, $temporaryProjectSettings, $utf8)
    $arguments = @('--headless', '--path', ('"{0}"' -f $project), '--export-debug', ('"{0}"' -f $presetName), ('"{0}"' -f $apk))
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $build 'export.stdout.log') -RedirectStandardError (Join-Path $build 'export.stderr.log')
    $null = $process.Handle
    if (-not $process.WaitForExit(300000)) { Stop-Process -Id $process.Id -Force; throw 'Android export timed out' }
    $process.WaitForExit()
    $errors = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $build 'export.stderr.log')
    if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Failed to export|Export failed|Could not find export template') { throw "Android export failed: $errors" }
    if (-not (Test-Path -LiteralPath $apk)) { throw 'APK missing' }
    $signature = & "$buildTools\apksigner.bat" verify --verbose --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
    $signature | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'signature.log')
    $alignment = & "$buildTools\zipalign.exe" -c -P 16 -v 4 $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed' }
    $alignment | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'alignment.log')
    $badging = & "$buildTools\aapt.exe" dump badging $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK metadata inspection failed' }
    $badging | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'package.log')
    $badgingText = $badging -join "`n"
    if (-not $badgingText.Contains("versionCode='$VersionCode'") -or -not $badgingText.Contains("versionName='$VersionName'")) { throw 'Unexpected APK version' }
    if (-not $badgingText.Contains("name='com.lastonboard.prototype'")) { throw 'Unexpected APK package' }
    foreach ($abi in $abis) {
        if (-not $badgingText.Contains($abi)) { throw "Missing APK ABI: $abi" }
    }
    if ($Architecture -eq 'arm64' -and $badgingText.Contains('armeabi-v7a')) { throw 'Unexpected ARMv7 payload in ARM64 build' }
    $manifest = @{
        built_at = [DateTime]::UtcNow.ToString('o')
        source_commit = $sourceCommit
        includes_working_tree = $sourceDirty
        model_sha256 = (Get-FileHash -LiteralPath (Join-Path $project 'redesign/model.gd') -Algorithm SHA256).Hash
        screen_sha256 = (Get-FileHash -LiteralPath (Join-Path $project 'redesign/screen.gd') -Algorithm SHA256).Hash
        sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
        size_bytes = (Get-Item -LiteralPath $apk).Length
        package = 'com.lastonboard.prototype'
        version_code = $VersionCode
        version_name = $VersionName
        game_loop = $modeSpec.game_loop
        play_mode = $PlayMode
        comparison_resources = @($comparisonResources)
        entry_script_sha256 = (Get-FileHash -LiteralPath (Join-Path $project $modeSpec.entry_script.Substring(6)) -Algorithm SHA256).Hash
        journey_sha256 = if ($PlayMode -eq 'magazine-journey') { (Get-FileHash -LiteralPath (Join-Path $project 'redesign/magazine_journey.gd') -Algorithm SHA256).Hash } else { $null }
        field_compression = 'run-owned compression cores; shop recharge; part-defined exceptions'
        content_sha256 = (Get-FileHash -LiteralPath (Join-Path $project 'redesign/content.gd') -Algorithm SHA256).Hash
        main_scene = $mainScene
        weapons = @('single','burst','scatter','heavy','amplifier')
        orientation = 'user landscape; Android screenOrientation 11'
        architectures = @($abis)
        excluded_source_art = @($exclusions.files)
        signing = 'standard local Android debug certificate; verified'
        alignment = 'zipalign 4-byte and 16KiB shared libraries verified'
        android_runtime = 'not tested on a device or emulator'
    }
    $manifest | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'build_manifest.json')
    $installSource = $modeSpec.install
    Copy-Item -LiteralPath (Join-Path $repo $installSource) -Destination (Join-Path $build 'INSTALL.md') -Force
    Add-Content -LiteralPath (Join-Path $build 'INSTALL.md') -Encoding UTF8 -Value ("`nThis package: " + ($abis -join ', '))
    Get-Item -LiteralPath $apk | Select-Object FullName, Length
    Write-Output "SHA256: $($manifest.sha256)"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:JAVA_HOME = $previousJavaHome
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    if ([IO.File]::ReadAllText($projectSettingsPath) -eq $temporaryProjectSettings) {
        [IO.File]::WriteAllBytes($projectSettingsPath, $originalProjectSettings)
    } else { Write-Warning 'Project settings changed during export; preserved the newer contents.' }
    if ((Test-Path -LiteralPath $presetPath) -and [IO.File]::ReadAllText($presetPath) -eq $temporaryContent) {
        if ($hadPreset) { [IO.File]::WriteAllBytes($presetPath, $original) }
        else { Remove-Item -LiteralPath $presetPath }
    }
}
