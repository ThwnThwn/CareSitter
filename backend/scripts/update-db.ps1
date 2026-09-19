[CmdletBinding()]
param(
    [int]$From = 10,
    [switch]$AllowDestructive,
    [string]$ContainerName = 'caresitter-db'
)

$ErrorActionPreference = 'Stop'

$backendRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $backendRoot 'docker-compose.yml'
$migrationDirectory = Join-Path $backendRoot 'init-db'
$destructiveMigrations = @(
    '19-drop-caregiver-availability.sql',
    '21-drop-caregiver-hourly-rate.sql'
)

function Invoke-DatabaseSql {
    param(
        [Parameter(Mandatory)][string]$Sql,
        [switch]$TupleOnly
    )

    if ($TupleOnly) {
        $output = & docker exec $ContainerName psql -v ON_ERROR_STOP=1 -U $script:databaseUser -d $script:databaseName -Atc $Sql
    }
    else {
        $output = & docker exec $ContainerName psql -v ON_ERROR_STOP=1 -U $script:databaseUser -d $script:databaseName -c $Sql
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Database command failed with exit code $LASTEXITCODE."
    }
    return $output
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found.'
}

Write-Host 'Starting PostgreSQL...'
& docker compose -f $composeFile up -d db
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to start the PostgreSQL service.'
}

$isHealthy = $false
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $health = & docker inspect --format '{{.State.Health.Status}}' $ContainerName 2>$null
    if ($health -eq 'healthy') {
        $isHealthy = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $isHealthy) {
    throw "Container '$ContainerName' did not become healthy within 60 seconds."
}

$container = (& docker inspect $ContainerName | ConvertFrom-Json)[0]
$containerEnvironment = @{}
foreach ($entry in $container.Config.Env) {
    $parts = $entry -split '=', 2
    if ($parts.Count -eq 2) {
        $containerEnvironment[$parts[0]] = $parts[1]
    }
}
$script:databaseUser = $containerEnvironment['POSTGRES_USER']
$script:databaseName = $containerEnvironment['POSTGRES_DB']
if ([string]::IsNullOrWhiteSpace($script:databaseUser) -or [string]::IsNullOrWhiteSpace($script:databaseName)) {
    throw "Container '$ContainerName' does not expose POSTGRES_USER and POSTGRES_DB."
}

Invoke-DatabaseSql 'CREATE TABLE IF NOT EXISTS public.schema_migrations (filename text PRIMARY KEY, checksum_sha256 varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());'

$migrations = Get-ChildItem $migrationDirectory -File |
    Where-Object {
        $_.Name -match '^(?<number>\d{2})-.*\.sql$' -and
        [int]$Matches.number -ge $From
    } |
    Sort-Object Name

foreach ($migration in $migrations) {
    if ($destructiveMigrations -contains $migration.Name -and -not $AllowDestructive) {
        Write-Warning "Skipping destructive migration $($migration.Name). Re-run with -AllowDestructive after verifying legacy data."
        continue
    }

    $fileName = $migration.Name
    $checksum = (Get-FileHash $migration.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumSql = 'SELECT checksum_sha256 FROM public.schema_migrations WHERE filename = ''{0}'';' -f $fileName
    $checksumRows = @(Invoke-DatabaseSql -Sql $checksumSql -TupleOnly)
    $storedChecksum = $checksumRows | Select-Object -Last 1
    if ($null -ne $storedChecksum) {
        $storedChecksum = $storedChecksum.Trim()
    }

    if ($storedChecksum -eq $checksum) {
        Write-Host "Already applied: $fileName"
        continue
    }
    if (-not [string]::IsNullOrWhiteSpace($storedChecksum)) {
        throw "Checksum mismatch for applied migration '$fileName'. Restore the original file and add a new migration instead."
    }

    $containerMigrationFile = "/docker-entrypoint-initdb.d/$fileName"
    Write-Host "Applying: $fileName"
    & docker exec $ContainerName psql -v ON_ERROR_STOP=1 -U $script:databaseUser -d $script:databaseName -f $containerMigrationFile
    if ($LASTEXITCODE -ne 0) {
        throw "Migration failed: $fileName"
    }

    $recordSql = 'INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES (''{0}'', ''{1}'');' -f $fileName, $checksum
    Invoke-DatabaseSql $recordSql
}

Write-Host 'Database upgrade completed.'
