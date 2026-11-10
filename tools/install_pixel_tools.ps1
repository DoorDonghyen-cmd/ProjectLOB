# Re-create the two installations at their recorded revisions. Never reset existing edits.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'art_tooling.lock.json') | ConvertFrom-Json
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable exited with $LASTEXITCODE" }
}
foreach ($id in @('pixeloe', 'pixelfx')) {
    $spec = $lock.sources.$id
    $source = $spec.local_source
    if (-not (Test-Path -LiteralPath (Join-Path $source '.git'))) {
        Invoke-Checked 'git' @('clone', '--no-checkout', $spec.repo, $source)
        Invoke-Checked 'git' @('-C', $source, 'checkout', '--detach', $spec.commit)
    }
    $head = & git -C $source rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -ne $spec.commit) { throw "Unexpected $id revision at $source; existing files preserved." }
    $dirty = & git -C $source status --porcelain --untracked-files=no
    if ($LASTEXITCODE -ne 0 -or $dirty) { throw "Modified $id source at $source; existing files preserved." }
}
$environment = $lock.sources.pixeloe.environment
$python = Join-Path $environment 'Scripts/python.exe'
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    $env:TEMP = Join-Path (Split-Path -Parent $environment) 'temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
    if (-not (Test-Path -LiteralPath $python)) { Invoke-Checked 'python' @('-m', 'venv', $environment) }
    Invoke-Checked $python @('-m', 'ensurepip', '--upgrade')
    Invoke-Checked $python @('-m', 'pip', 'install', '--disable-pip-version-check', '-r', (Join-Path $PSScriptRoot 'pixeloe_requirements.lock.txt'))
    Invoke-Checked $python @('-m', 'pip', 'install', '--disable-pip-version-check', '--no-deps', $lock.sources.pixeloe.local_source)
    Invoke-Checked $python @('-m', 'pip', 'check')
} finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
Write-Output 'Installed pinned PixelOE and pixelfx. Run python tools/check_pixel_tools.py.'
