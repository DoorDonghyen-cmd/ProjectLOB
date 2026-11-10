param([int]$Port = 8766, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$url = "http://127.0.0.1:$Port"
$repo = Split-Path -Parent $PSScriptRoot
$qa = Join-Path $repo 'qa_runtime/pixelfx_gallery'
New-Item -ItemType Directory -Force -Path $qa | Out-Null
function Test-Gallery {
    try {
        $response = Invoke-RestMethod "$url/_lob_pixelfx" -TimeoutSec 1
        return $response.tool -eq 'LoB pixelfx'
    } catch { return $false }
}
if (-not (Test-Gallery)) {
    $node = (Get-Command node -ErrorAction Stop).Source
    $script = Join-Path $PSScriptRoot 'pixelfx.mjs'
    $process = Start-Process -FilePath $node -ArgumentList @(('"{0}"' -f $script), 'gallery', $Port) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qa 'stdout.log') -RedirectStandardError (Join-Path $qa 'stderr.log')
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Gallery)) {
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) {
            if (-not $process.HasExited) { Stop-Process -Id $process.Id }
            throw "pixelfx gallery could not start. See $qa/stderr.log"
        }
        Start-Sleep -Milliseconds 200
    }
    $process.Id | Set-Content -LiteralPath (Join-Path $qa 'server.pid')
}
Write-Output "$url/gallery/"
if (-not $NoBrowser) { Start-Process "$url/gallery/" }
