[CmdletBinding()]
param(
    [string]$ContainerName = 'caresitter-db',
    [ValidateRange(1, 10)]
    [int]$Repeat = 3
)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found.'
}

$container = (& docker inspect $ContainerName | ConvertFrom-Json)[0]
if ($null -eq $container -or $container.State.Running -ne $true) {
    throw "PostgreSQL container '$ContainerName' is not running."
}

$containerEnvironment = @{}
foreach ($entry in $container.Config.Env) {
    $parts = $entry -split '=', 2
    if ($parts.Count -eq 2) {
        $containerEnvironment[$parts[0]] = $parts[1]
    }
}

$databaseUser = $containerEnvironment['POSTGRES_USER']
$databasePassword = $containerEnvironment['POSTGRES_PASSWORD']
if ([string]::IsNullOrWhiteSpace($databaseUser) -or
    [string]::IsNullOrWhiteSpace($databasePassword)) {
    throw "Container '$ContainerName' does not expose PostgreSQL test credentials."
}

$env:CARESITTER_TEST_ADMIN_CONNECTION =
    "Host=localhost;Port=5432;Database=postgres;Username=$databaseUser;Password=$databasePassword"

Push-Location $backendRoot
try {
    for ($run = 1; $run -le $Repeat; $run++) {
        Write-Host "Phase 8 acceptance run $run/$Repeat"
        & dotnet test tests/CareSitter.IntegrationTests/CareSitter.IntegrationTests.csproj `
            --nologo `
            --filter 'FullyQualifiedName~BookingFlowTests|FullyQualifiedName~BookingTransactionIntegrityTests|FullyQualifiedName~RaceTests'
        if ($LASTEXITCODE -ne 0) {
            throw "Phase 8 acceptance run $run failed with exit code $LASTEXITCODE."
        }
    }
}
finally {
    Pop-Location
    Remove-Item Env:CARESITTER_TEST_ADMIN_CONNECTION -ErrorAction SilentlyContinue
}
