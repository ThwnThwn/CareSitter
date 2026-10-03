[CmdletBinding()]
param(
    # Omit to create a disposable local PostGIS server.
    [string]$ContainerName,
    [ValidateRange(1, 10)]
    [int]$Repeat = 1,
    [string]$Filter = 'Category=PostgreSQL',
    [string]$ArtifactsDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$backendRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $backendRoot 'tests/CareSitter.IntegrationTests/CareSitter.IntegrationTests.csproj'
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$ownedContainerId = $null
$previousAdminConnection = $env:CARESITTER_TEST_ADMIN_CONNECTION

if ([string]::IsNullOrWhiteSpace($ArtifactsDirectory)) {
    $ArtifactsDirectory = Join-Path $backendRoot "artifacts/postgres/$runId"
}
$ArtifactsDirectory = [System.IO.Path]::GetFullPath($ArtifactsDirectory)

function Get-TestContainer {
    param([Parameter(Mandatory)][string]$Name)
    $json = & docker inspect $Name
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect PostgreSQL container '$Name'." }
    $containers = @($json | ConvertFrom-Json)
    if ($containers.Count -ne 1 -or -not $containers[0].State.Running) {
        throw "PostgreSQL container '$Name' is not running."
    }
    return $containers[0]
}

try {
    foreach ($command in @('docker', 'dotnet')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Required command '$command' was not found."
        }
    }
    # We connect to a localhost port, never to a remote Docker host.
    $contextJson = & docker context inspect
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the active Docker context.' }
    $context = @($contextJson | ConvertFrom-Json)[0]
    $dockerEndpoint = if ($env:DOCKER_HOST) { $env:DOCKER_HOST } else { $context.Endpoints.docker.Host }
    if ($dockerEndpoint -notmatch '^(npipe|unix)://') {
        throw 'Use a local Docker context for PostgreSQL tests; remote Docker hosts are not supported.'
    }
    & docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) { throw 'Docker is not ready. Start Docker Desktop and try again.' }

    if ([string]::IsNullOrWhiteSpace($ContainerName)) {
        $ContainerName = "caresitter-postgres-tests-$runId"
        $password = [Guid]::NewGuid().ToString('N')
        $created = & docker run --detach --rm --name $ContainerName `
            --label "caresitter.test-run=$runId" `
            --env POSTGRES_USER=race_test --env "POSTGRES_PASSWORD=$password" `
            --env POSTGRES_DB=postgres --publish '127.0.0.1::5432' `
            postgis/postgis:16-3.4
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($created)) {
            throw 'Unable to create the isolated PostgreSQL test container.'
        }
        $ownedContainerId = $created.Trim()
    }

    $container = Get-TestContainer -Name $ContainerName
    $containerEnvironment = @{}
    foreach ($entry in $container.Config.Env) {
        $parts = $entry -split '=', 2
        if ($parts.Count -eq 2) { $containerEnvironment[$parts[0]] = $parts[1] }
    }
    $databaseUser = $containerEnvironment['POSTGRES_USER']
    $databasePassword = $containerEnvironment['POSTGRES_PASSWORD']
    if ([string]::IsNullOrWhiteSpace($databaseUser) -or [string]::IsNullOrWhiteSpace($databasePassword)) {
        throw "Container '$ContainerName' must provide POSTGRES_USER and POSTGRES_PASSWORD."
    }
    $portProperty = $container.NetworkSettings.Ports.PSObject.Properties['5432/tcp']
    $bindings = if ($null -ne $portProperty) { @($portProperty.Value) } else { @() }
    $binding = $bindings | Where-Object { $_.HostIp -in @('127.0.0.1', '0.0.0.0') } | Select-Object -First 1
    if ($null -eq $binding) { throw "Container '$ContainerName' has no local IPv4 port published for PostgreSQL." }
    $databasePort = [int]$binding.HostPort

    # A TCP SQL query avoids the socket-only temporary server used at init time.
    $ready = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        try {
            $answer = & docker exec --env "PGPASSWORD=$databasePassword" $ContainerName `
                psql -h 127.0.0.1 -U $databaseUser -d postgres -Atc 'SELECT 1' 2>$null
        }
        catch { $answer = $null }
        if ($LASTEXITCODE -eq 0 -and $answer -eq '1') { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw "PostgreSQL in '$ContainerName' did not become ready." }

    # Quote connection-string values and never print credentials to logs.
    $quotedUser = '"' + $databaseUser.Replace('"', '""') + '"'
    $quotedPassword = '"' + $databasePassword.Replace('"', '""') + '"'
    $env:CARESITTER_TEST_ADMIN_CONNECTION =
        "Host=127.0.0.1;Port=$databasePort;Database=postgres;Username=$quotedUser;Password=$quotedPassword"

    New-Item -ItemType Directory -Force -Path $ArtifactsDirectory | Out-Null
    for ($run = 1; $run -le $Repeat; $run++) {
        $resultName = "postgres-$runId-run-$run.trx"
        Write-Host "PostgreSQL tests $run/$Repeat on isolated test databases via localhost:$databasePort"
        & dotnet test $project --nologo --filter $Filter `
            --results-directory $ArtifactsDirectory --logger "trx;LogFileName=$resultName" --verbosity minimal
        if ($LASTEXITCODE -ne 0) { throw "PostgreSQL test run $run failed. Results: $ArtifactsDirectory" }

        [xml]$trx = Get-Content -Raw -LiteralPath (Join-Path $ArtifactsDirectory $resultName)
        $counters = $trx.TestRun.ResultSummary.Counters
        if ([int]$counters.total -eq 0 -or [int]$counters.notExecuted -ne 0 -or
            [int]$counters.passed -ne [int]$counters.total) {
            throw "Test run $run did not execute and pass every selected test. Inspect the TRX results."
        }
        Write-Host "PASS: $($counters.passed)/$($counters.total); skipped: $($counters.notExecuted)"
    }
    Write-Host "Evidence: $ArtifactsDirectory"
}
finally {
    $env:CARESITTER_TEST_ADMIN_CONNECTION = $previousAdminConnection
    # Remove only the exact container created here, never a reused dev container.
    if ($null -ne $ownedContainerId) {
        & docker rm --force $ownedContainerId | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "Could not remove test container '$ContainerName'." }
        else { Write-Host "Removed disposable test container '$ContainerName'." }
    }
}
