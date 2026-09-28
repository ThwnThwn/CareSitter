[CmdletBinding()]
param(
    [switch]$Force,
    [string]$TestPassword = 'CareSitter123!'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $backendRoot 'docker-compose.yml'
$databaseContainer = 'caresitter-db'

if (-not $Force) {
    throw 'This command deletes the CareSitter local Docker database and RedisInsight volumes. Re-run with -Force to confirm.'
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found.'
}

& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker daemon is not running.'
}

Write-Host 'Stopping only the services and named volumes owned by backend/docker-compose.yml...'
& docker compose -f $composeFile down --volumes --remove-orphans
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to reset the CareSitter local Docker environment.'
}

Write-Host 'Starting a clean PostgreSQL and Redis environment...'
& docker compose -f $composeFile up -d db redis
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to start PostgreSQL and Redis.'
}

foreach ($containerName in @('caresitter-db', 'caresitter-redis')) {
    $healthy = $false
    for ($attempt = 1; $attempt -le 45; $attempt++) {
        $health = & docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' $containerName 2>$null
        if ($health -eq 'healthy') {
            $healthy = $true
            break
        }
        Start-Sleep -Seconds 2
    }

    if (-not $healthy) {
        throw "Container '$containerName' did not become healthy within 90 seconds."
    }
}

$container = (& docker inspect $databaseContainer | ConvertFrom-Json)[0]
$containerEnvironment = @{}
foreach ($entry in $container.Config.Env) {
    $parts = $entry -split '=', 2
    if ($parts.Count -eq 2) {
        $containerEnvironment[$parts[0]] = $parts[1]
    }
}

$databaseUser = $containerEnvironment['POSTGRES_USER']
$databaseName = $containerEnvironment['POSTGRES_DB']
if ([string]::IsNullOrWhiteSpace($databaseUser) -or
    [string]::IsNullOrWhiteSpace($databaseName)) {
    throw 'The PostgreSQL container does not expose POSTGRES_USER and POSTGRES_DB.'
}

$schemaReady = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    $latestColumn = & docker exec $databaseContainer psql `
        -U $databaseUser `
        -d $databaseName `
        -Atc "SELECT column_name FROM information_schema.columns WHERE table_schema = 'identity' AND table_name = 'users' AND column_name = 'avatar_url';" `
        2>$null
    if ($LASTEXITCODE -eq 0 -and $latestColumn -eq 'avatar_url') {
        $schemaReady = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $schemaReady) {
    throw 'The clean database did not finish applying all migrations within 120 seconds.'
}

$escapedPassword = $TestPassword.Replace("'", "''")
$seedUserIds = @(
    'a0000000-0000-0000-0000-0000000000a1',
    'a0000000-0000-0000-0000-0000000000c1',
    'a0000000-0000-0000-0000-0000000000e1',
    'a0000000-0000-0000-0000-0000000000e3',
    'a0000000-0000-0000-0000-0000000000e5',
    'a0000000-0000-0000-0000-0000000000e7'
)
$idList = ($seedUserIds | ForEach-Object { "'$_'::uuid" }) -join ', '
$sql = "UPDATE identity.users SET password_hash = crypt('$escapedPassword', gen_salt('bf', 12)) WHERE id IN ($idList);"

& docker exec $databaseContainer psql `
    -v ON_ERROR_STOP=1 `
    -U $databaseUser `
    -d $databaseName `
    -c $sql
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to initialize the local test-account passwords.'
}

Write-Host 'Local environment reset completed.'
Write-Host 'Seed accounts: admin@caresitter.vn, nguoithan@example.com, nguoicham@example.com'
Write-Host 'All seed accounts use the TestPassword supplied to this command.'
