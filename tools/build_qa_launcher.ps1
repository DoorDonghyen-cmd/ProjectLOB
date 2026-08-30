param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourcePath = Join-Path $PSScriptRoot "qa_launcher\Program.cs"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "ProjectLoB-QA.exe"
} else {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}

$compilerCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$compilerPath = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($compilerPath)) {
    throw "The Windows .NET Framework C# compiler was not found."
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Launcher source was not found: $sourcePath"
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

& $compilerPath /nologo /target:exe /platform:anycpu /optimize+ "/out:$OutputPath" $sourcePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw "QA launcher compilation failed with exit code $LASTEXITCODE."
}

& $OutputPath --check
if ($LASTEXITCODE -ne 0) {
    throw "The compiled QA launcher failed its self-check."
}

$file = Get-Item -LiteralPath $OutputPath
Write-Output "QA launcher built: $($file.FullName) ($($file.Length) bytes)"
