param(
    [string]$VersionName = '',
    [string]$NotesFile = '',
    [string]$GodotPath = 'D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe',
    [string]$AndroidSdk = '',
    [ValidateSet('universal', 'arm64')][string]$Architecture = 'universal'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$mobileRoot = Join-Path $repo 'builds\mobile'
$releaseRoot = Join-Path $mobileRoot 'releases'
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
# One export at a time: Godot temporarily uses a generated export preset.
$lock = $null
try {
    $lock = [IO.File]::Open((Join-Path $mobileRoot 'build.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if (-not $VersionName) { $VersionName = '0.5.' + (Get-Date -Format 'yyyyMMdd.HHmmss') }
    if ($VersionName -notmatch '^[0-9A-Za-z.-]+$') { throw 'VersionName may contain only letters, numbers, dots and hyphens.' }
    $versionCode = [int](Get-Date -Format 'yyyyMMdd')
    # Even a failed upload reserves its version. Never downgrade on a same-day build.
    $manifests = @(Get-ChildItem -LiteralPath $releaseRoot -Filter 'build_manifest.json' -File -Recurse)
    $legacyManifest = Join-Path $repo 'builds\city-android\build_manifest.json'
    if (Test-Path -LiteralPath $legacyManifest) { $manifests += Get-Item -LiteralPath $legacyManifest }
    foreach ($file in $manifests) {
        $prior = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $versionCode = [Math]::Max($versionCode, [int]$prior.version_code + 1)
    }
    if ($versionCode -gt 2100000000) { throw 'Android version code limit reached.' }
    $buildId = "LastOnBoard-$stamp-v$versionCode"
    $release = Join-Path $releaseRoot $buildId
    if (Test-Path -LiteralPath $release) { throw 'Build ID already exists; wait one second and retry.' }
    New-Item -ItemType Directory -Path $release | Out-Null
    Write-Output "Building $buildId"
    $exportOptions = @{ GodotPath = $GodotPath; VersionCode = $versionCode; VersionName = $VersionName; OutputDirectory = $release; Architecture = $Architecture }
    if ($AndroidSdk) { $exportOptions.AndroidSdk = $AndroidSdk }
    & (Join-Path $PSScriptRoot 'export_city_android.ps1') @exportOptions
    $manifestFile = Join-Path $release 'build_manifest.json'
    $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $apk = Join-Path $release 'LastOnBoard-city.apk'
    # Check the exported resource set and CRC; keep the private probe outside ZIP.
    & python (Join-Path $PSScriptRoot 'mobile_release.py') verify --release $release --godot $GodotPath
    if ($LASTEXITCODE -ne 0) { throw 'APK content validation failed.' }
    $notes = Join-Path $release 'RELEASE_NOTES.md'
    if ($NotesFile) {
        Copy-Item -LiteralPath $NotesFile -Destination $notes
    } else {
        $text = "# Last on Board $VersionName`n`nBuild: $buildId`n`nCurrent working tree, including uncommitted game changes.`nSee INSTALL.md for installation steps.`n"
        [IO.File]::WriteAllText($notes, $text, [Text.UTF8Encoding]::new($false))
    }
    & python (Join-Path $PSScriptRoot 'mobile_release.py') package --release $release
    if ($LASTEXITCODE -ne 0) { throw 'ZIP packaging failed.' }
    $package = Get-Content -LiteralPath (Join-Path $release 'delivery_request.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $package | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mobileRoot 'latest.json') -Encoding UTF8
    Write-Output "APK: $apk"
    Write-Output "ZIP: $($package.zip_path)"
    Write-Output "Upload request: $(Join-Path $release 'delivery_request.json')"
    Write-Output 'READY_FOR_DRIVE_UPLOAD (upload is performed by the connected Google Drive workflow)'
} finally {
    if ($lock) { $lock.Dispose() }
}
