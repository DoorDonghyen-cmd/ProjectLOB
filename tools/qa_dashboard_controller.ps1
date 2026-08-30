param(
    [string]$GodotPath = "",
    [ValidateRange(1024, 65535)][int]$Port = 8765
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$dashboardRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "docs\qa\dashboard"))
$runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "qa_runtime"))
$statusPath = Join-Path $runtimeRoot "controller_status.json"
$requestPath = Join-Path $runtimeRoot "launch_request.json"
$runnerPath = Join-Path $PSScriptRoot "qa_run_playtest.ps1"

function Resolve-GodotPath {
    param([string]$Requested)
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Requested)) { $candidates.Add($Requested) }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) { $candidates.Add($env:GODOT_BIN) }
    foreach ($name in @("godot", "godot4", "Godot")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $candidates.Add($command.Source) }
    }
    foreach ($folder in @(
        (Join-Path $env:USERPROFILE "OneDrive\Desktop"),
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "Downloads")
    )) {
        if (Test-Path -LiteralPath $folder) {
            Get-ChildItem -LiteralPath $folder -Filter "Godot_v4*_console.exe" -File -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { $candidates.Add($_.FullName) }
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [System.IO.Path]::GetFullPath($candidate) }
    }
    return ""
}

function Write-HttpResponse {
    param($Stream, [int]$StatusCode, [string]$ContentType, [byte[]]$Bytes)
    $reason = switch ($StatusCode) { 200 { "OK" } 202 { "Accepted" } 400 { "Bad Request" } 404 { "Not Found" } 409 { "Conflict" } default { "Internal Server Error" } }
    $header = "HTTP/1.1 $StatusCode $reason`r`nContent-Type: $ContentType`r`nContent-Length: $($Bytes.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($Bytes.Length -gt 0) { $Stream.Write($Bytes, 0, $Bytes.Length) }
    $Stream.Flush()
}

function Write-JsonResponse {
    param($Stream, [int]$StatusCode, $Value)
    $json = $Value | ConvertTo-Json -Depth 12
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    Write-HttpResponse $Stream $StatusCode "application/json; charset=utf-8" $bytes
}

function Read-Status {
    if (-not (Test-Path -LiteralPath $statusPath)) {
        return @{ state = "idle"; progress = 0; message = "Ready to start QA"; controller = "online" }
    }
    try {
        $status = Get-Content -Raw -Encoding UTF8 -LiteralPath $statusPath | ConvertFrom-Json
        $status | Add-Member -NotePropertyName controller -NotePropertyValue "online" -Force
        return $status
    } catch {
        return @{ state = "failed"; progress = 0; message = "Cannot read status file"; error = $_.Exception.Message; controller = "online" }
    }
}

function Serve-File {
    param($Stream, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath -eq "/") { $RelativePath = "index.html" }
    $RelativePath = [Uri]::UnescapeDataString($RelativePath.TrimStart('/')).Replace('/', [IO.Path]::DirectorySeparatorChar)
    $absolute = [System.IO.Path]::GetFullPath((Join-Path $dashboardRoot $RelativePath))
    if (-not $absolute.StartsWith($dashboardRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        Write-HttpResponse $Stream 404 "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes("Not Found"))
        return
    }
    $mime = switch ([IO.Path]::GetExtension($absolute).ToLowerInvariant()) {
        ".html" { "text/html; charset=utf-8" }
        ".css" { "text/css; charset=utf-8" }
        ".js" { "application/javascript; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        ".png" { "image/png" }
        default { "application/octet-stream" }
    }
    $bytes = [IO.File]::ReadAllBytes($absolute)
    Write-HttpResponse $Stream 200 $mime $bytes
}

$resolvedGodot = Resolve-GodotPath $GodotPath
if ([string]::IsNullOrWhiteSpace($resolvedGodot)) {
    throw "Godot console executable not found. Set -GodotPath or GODOT_BIN."
}
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "ProjectLoB QA Dashboard Controller"
Write-Host "Dashboard: http://127.0.0.1:$Port/"
Write-Host "Godot: $resolvedGodot"
Write-Host "Stop: Ctrl+C"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        try {
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) { throw "Empty request" }
            $parts = $requestLine.Split(' ')
            if ($parts.Count -lt 2) { throw "Invalid request line" }
            $method = $parts[0].ToUpperInvariant()
            $path = ([Uri]("http://127.0.0.1" + $parts[1])).AbsolutePath
            $headers = @{}
            while ($true) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($line)) { break }
                $separator = $line.IndexOf(':')
                if ($separator -gt 0) { $headers[$line.Substring(0, $separator).Trim().ToLowerInvariant()] = $line.Substring($separator + 1).Trim() }
            }
            $body = ""
            $contentLength = if ($headers.ContainsKey("content-length")) { [int]$headers["content-length"] } else { 0 }
            if ($contentLength -gt 0) {
                $buffer = New-Object char[] $contentLength
                $read = 0
                while ($read -lt $contentLength) {
                    $count = $reader.Read($buffer, $read, $contentLength - $read)
                    if ($count -le 0) { break }
                    $read += $count
                }
                $body = -join $buffer[0..([Math]::Max(0, $read - 1))]
            }
            if ($path -eq "/api/qa/status" -and $method -eq "GET") {
                Write-JsonResponse $stream 200 (Read-Status)
                continue
            }
            if ($path -eq "/api/qa/start" -and $method -eq "POST") {
                $current = Read-Status
                if ([string]$current.state -in @("queued", "running", "integrating")) {
                    Write-JsonResponse $stream 409 $current
                    continue
                }
                $input = if ([string]::IsNullOrWhiteSpace($body)) { @{} } else { $body | ConvertFrom-Json }
                $seed = [Math]::Max(1, [int]$input.gameplay_seed)
                if ($seed -eq 1 -and $null -eq $input.gameplay_seed) { $seed = 424242 }
                $encounters = [Math]::Min(6, [Math]::Max(1, [int]$input.target_encounters))
                if ($encounters -eq 1 -and $null -eq $input.target_encounters) { $encounters = 3 }
                $requestId = "qa-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmss")
                $request = @{
                    schema_version = 1
                    request_id = $requestId
                    idempotency_key = $requestId
                    mode = "fun_and_bug_playtest"
                    gameplay_seed = $seed
                    target_encounters = $encounters
                    profiles = @("beginner", "aggressive", "conservative", "experimental")
                    requested_at = [DateTime]::UtcNow.ToString("o")
                }
                $request | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $requestPath
                $initial = @{
                    request_id = $requestId; state = "queued"; stage = "queue"; progress = 0
                    message = "Preparing QA playtest"; requested_at = [DateTime]::UtcNow.ToString("o")
                    controller = "online"
                }
                $initial | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statusPath
                $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ('"{0}"' -f $runnerPath),
                    "-GodotPath", ('"{0}"' -f $resolvedGodot), "-RequestPath", ('"{0}"' -f $requestPath))
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -PassThru -WindowStyle Hidden
                $initial["process_id"] = $process.Id
                $initial | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statusPath
                Write-JsonResponse $stream 202 $initial
                continue
            }
            if ($path -eq "/api/qa/cancel" -and $method -eq "POST") {
                $current = Read-Status
                foreach ($id in @($current.child_process_id, $current.process_id)) {
                    if ($null -ne $id) { try { Stop-Process -Id ([int]$id) -Force } catch { } }
                }
                $cancelled = @{ state = "cancelled"; stage = "cancelled"; progress = $current.progress; message = "QA run cancelled by user"; controller = "online"; updated_at = [DateTime]::UtcNow.ToString("o") }
                $cancelled | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statusPath
                Write-JsonResponse $stream 200 $cancelled
                continue
            }
            Serve-File $stream $path
        } catch {
            try { Write-JsonResponse $stream 500 @{ state = "failed"; error = $_.Exception.Message } } catch { }
        } finally {
            $stream.Close()
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
