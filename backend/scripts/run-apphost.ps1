[CmdletBinding()]
param(
    [string]$DotnetPath,
    [string]$AspirePath,
    [switch]$NoBuild,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AppHostArguments
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$orchestrationPath = Join-Path $repositoryPath 'backend/orchestration'
if (-not $DotnetPath) {
    $candidates = @(
        (Get-Command dotnet -ErrorAction SilentlyContinue).Source,
        (Join-Path $repositoryPath '.codex-build/dotnet10/dotnet.exe'),
        (Join-Path (Split-Path -Parent $repositoryPath) '.codex-build/dotnet10/dotnet.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate) -and
            ((& $candidate --list-sdks) -match '^10\.0\.4\d+ ')) {
            $DotnetPath = $candidate
            break
        }
    }
}
if (-not $DotnetPath) { throw 'Cần SDK .NET 10.0.401 cho AppHost. API và Nutrition vẫn dùng .NET 8. Có thể truyền -DotnetPath đến SDK đã cài.' }
if (-not $AspirePath) {
    foreach ($candidate in @((Get-Command aspire -ErrorAction SilentlyContinue).Source,
        (Join-Path $env:USERPROFILE '.aspire/bin/aspire.exe'),
        (Join-Path $repositoryPath '.codex-build/aspire/aspire.exe'),
        (Join-Path (Split-Path -Parent $repositoryPath) '.codex-build/aspire/aspire.exe'))) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { $AspirePath = $candidate; break }
    }
}
if (-not $AspirePath) { throw 'Cần Aspire CLI 13.6.1 cho AppHost. Có thể truyền -AspirePath đến aspire.exe đã cài.' }
$DotnetPath = (Resolve-Path -LiteralPath $DotnetPath).Path
$AspirePath = (Resolve-Path -LiteralPath $AspirePath).Path

$arguments = @('run', '--project', 'CareSitter.AppHost/CareSitter.AppHost.csproj', '--launch-profile', 'http')
$arguments += "-p:AspireCliPath=$AspirePath"
$arguments += '-p:ASPIRE_SUPPRESS_CLI_RUN_HOOK=true'
if ($NoBuild) { $arguments += '--no-build' }
if ($AppHostArguments) { $arguments += '--'; $arguments += $AppHostArguments }
Push-Location -LiteralPath $orchestrationPath
$previousPath = $env:PATH
$previousDotnetRoot = $env:DOTNET_ROOT
try {
    # The Aspire CLI resolves dotnet from PATH even when dotnet run was invoked by absolute path.
    $sdkDirectory = Split-Path -Parent $DotnetPath
    $env:PATH = "$sdkDirectory$([System.IO.Path]::PathSeparator)$previousPath"
    $env:DOTNET_ROOT = $sdkDirectory
    & $DotnetPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "AppHost kết thúc với mã $LASTEXITCODE." }
}
finally { $env:PATH = $previousPath; $env:DOTNET_ROOT = $previousDotnetRoot; Pop-Location }
