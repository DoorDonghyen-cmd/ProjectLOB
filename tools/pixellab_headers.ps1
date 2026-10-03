# Machine-only MCP credential helper. Do not run this script in a visible log.
$ErrorActionPreference = 'Stop'
$token = [Environment]::GetEnvironmentVariable('LOB_PIXELLAB_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = [Environment]::GetEnvironmentVariable('LOB_PIXELLAB_API_KEY', 'Process')
}
if ([string]::IsNullOrWhiteSpace($token)) { throw 'PixelLab token is not configured.' }
$token = $token.Trim() -replace '^Bearer\s+', ''
@{ Authorization = 'Bearer ' + $token } | ConvertTo-Json -Compress | Write-Output
$token = $null
