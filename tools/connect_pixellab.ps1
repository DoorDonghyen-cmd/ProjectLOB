param([switch]$CheckOnly, [switch]$UseStoredKey)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent (Split-Path -Parent $repo)
$configPaths = @((Join-Path $workspace '.codex/config.toml'), (Join-Path $repo '.codex/config.toml'))
$tokenName = 'LOB_PIXELLAB_API_KEY'
if ($CheckOnly) {
    [PSCustomObject]@{
        ConfigsExist = @($configPaths | ForEach-Object { Test-Path -LiteralPath $_ })
        TokenReadableInThisUserContext = [bool][Environment]::GetEnvironmentVariable($tokenName, 'User')
    } | ConvertTo-Json -Compress | Write-Output
    exit 0
}
$pattern = '(?ms)(^\[mcp_servers\.lob_pixellab\][ \t]*\r?\n)(.*?)(?=^\[|\z)'
$helperPath = Join-Path $PSScriptRoot 'pixellab_headers.ps1'
if (-not (Test-Path -LiteralPath $helperPath)) { throw 'PixelLab credential helper is missing.' }
$helperCommand = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $helperPath + '"'
$helperLine = 'http_headers_helper = ' + (ConvertTo-Json -InputObject $helperCommand -Compress)
$updates = @{}
foreach ($configPath in $configPaths) {
    if (-not (Test-Path -LiteralPath $configPath)) { throw 'Project MCP config is missing.' }
    $configText = [IO.File]::ReadAllText($configPath)
    $serverMatch = [regex]::Match($configText, $pattern)
    if (-not $serverMatch.Success) { throw 'PixelLab MCP entry is missing.' }
    $body = $serverMatch.Groups[2].Value.Replace("`r`n", "`n")
    if ($body -match '(?m)^enabled\s*=') {
        $body = [regex]::Replace($body, '(?m)^enabled[ \t]*=[ \t]*(true|false)[ \t]*$', 'enabled = true')
    } else { $body = "enabled = true`n" + $body }
    # Read the Windows user key at connection time; GUI processes may retain old environment values.
    $body = [regex]::Replace($body, '(?m)^bearer_token_env_var[ \t]*=.*\n?', '')
    if ($body -match '(?m)^http_headers_helper[ \t]*=') {
        $body = [regex]::Replace($body, '(?m)^http_headers_helper[ \t]*=.*$', [Text.RegularExpressions.MatchEvaluator]{ param($match) $helperLine })
    } else { $body = $body.TrimEnd() + "`n" + $helperLine + "`n" }
    if ($body -notmatch '(?m)^enabled = true$') { throw 'PixelLab activation could not be prepared.' }
    $replacement = $serverMatch.Groups[1].Value + $body
    $updates[$configPath] = $configText.Substring(0, $serverMatch.Index) + $replacement + $configText.Substring($serverMatch.Index + $serverMatch.Length)
}
if ($UseStoredKey) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($tokenName, 'User'))) {
        throw 'No saved PixelLab token is readable in this Windows user context.'
    }
} else {
    Write-Host 'Create/sign in to your PixelLab account and obtain its MCP/API token.'
    Write-Host 'The token is stored in your Windows user environment, never in Git or chat.'
    $secureToken = Read-Host 'PixelLab token (input is hidden)' -AsSecureString
    if ($secureToken.Length -eq 0) { throw 'No token entered; configuration unchanged.' }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim() -replace '^Bearer\s+', ''
        if ([string]::IsNullOrWhiteSpace($plainToken)) { throw 'No token entered; configuration unchanged.' }
        [Environment]::SetEnvironmentVariable($tokenName, $plainToken, 'User')
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $plainToken = $null
        $secureToken.Dispose()
    }
}
foreach ($configPath in $configPaths) {
    [IO.File]::WriteAllText($configPath, $updates[$configPath], [Text.UTF8Encoding]::new($false))
}
Write-Host 'PixelLab enabled in both project configs. The credential helper reads your saved key at connection time.'
Write-Host 'Restart Codex to refresh its MCP tool list. No asset generation has been requested.'
