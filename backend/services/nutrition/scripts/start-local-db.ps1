param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [ValidateRange(1024, 65535)][int]$Port = 5437
)

$ErrorActionPreference = 'Stop'
$serviceRoot = Split-Path $PSScriptRoot -Parent
$backendRoot = [IO.Path]::GetFullPath((Join-Path $serviceRoot '../..'))
$stateRoot = Join-Path $backendRoot 'artifacts/nutrition-local'
$dataPath = Join-Path $stateRoot 'data'
$configPath = Join-Path $serviceRoot 'nutrition-db.local.json'
$schemaPath = Join-Path $backendRoot 'init-db/nutrition-service/01-nutrition-workflow.sql'
$rolePath = Join-Path $backendRoot 'init-db/nutrition-service/02-runtime-role.sql'
$catalogPath = Join-Path $backendRoot 'init-db/nutrition-service/03-catalog-governance.sql'
$constraintPath = Join-Path $backendRoot 'init-db/nutrition-service/04-catalog-nutrient-constraints.sql'
$citationPath = Join-Path $backendRoot 'init-db/nutrition-service/05-recipe-source-citations.sql'
foreach ($program in @('initdb.exe', 'pg_ctl.exe', 'psql.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $PostgresBin $program))) { throw "Missing PostgreSQL tool: $program" }
}
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$bootstrapLock = [IO.File]::Open((Join-Path $stateRoot 'startup.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    if (!(Test-Path -LiteralPath $configPath)) {
        if (Test-Path -LiteralPath (Join-Path $dataPath 'PG_VERSION')) { throw 'Existing cluster has no local credential file. Restore the credential file before continuing.' }
        $adminPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        $appPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        @{
            Port = $Port
            DataDirectory = $dataPath
            AdminConnection = "Host=127.0.0.1;Port=$Port;Database=postgres;Username=postgres;Password=$adminPassword"
            ConnectionStrings = @{ Nutrition = "Host=127.0.0.1;Port=$Port;Database=nutrition;Username=nutrition_app;Password=$appPassword" }
            AdminPassword = $adminPassword
            AppPassword = $appPassword
        } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $configPath -Encoding utf8
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($config.AdminPassword -notmatch '^[A-F0-9]{64}$' -or $config.AppPassword -notmatch '^[A-F0-9]{64}$') {
        throw 'The local credential file does not match the generated configuration format.'
    }
    if ($config.Port -ne $Port -or [IO.Path]::GetFullPath($config.DataDirectory) -ne [IO.Path]::GetFullPath($dataPath)) {
        throw 'Port or cluster path differs from the saved configuration. Use the original port and state directory.'
    }
    $previousPassword = $env:PGPASSWORD
    try {
        if (!(Test-Path -LiteralPath (Join-Path $dataPath 'PG_VERSION'))) {
            $passwordFile = Join-Path $stateRoot ('init-' + [Guid]::NewGuid().ToString('N') + '.tmp')
            try {
                [IO.File]::WriteAllText($passwordFile, $config.AdminPassword)
                & (Join-Path $PostgresBin 'initdb.exe') -D $dataPath -U postgres --encoding=UTF8 --locale=C --auth=scram-sha-256 --pwfile=$passwordFile
                if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL initialization failed; state was retained for inspection.' }
            } finally {
                if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile }
            }
        }
        & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataPath status *> $null
        if ($LASTEXITCODE -ne 0) {
            & (Join-Path $PostgresBin 'pg_ctl.exe') -D $dataPath -l (Join-Path $stateRoot 'postgres.log') -o "-h 127.0.0.1 -p $Port" -w start
            if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL could not start. Check the local log and port.' }
        }
        $env:PGPASSWORD = $config.AdminPassword
        $psql = Join-Path $PostgresBin 'psql.exe'
        $arguments = @('-X', '-h', '127.0.0.1', '-p', "$Port", '-U', 'postgres', '-v', 'ON_ERROR_STOP=1')
        $actualPath = & $psql @arguments -d postgres -Atc 'SHOW data_directory'
        if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($actualPath.Trim()) -ne [IO.Path]::GetFullPath($dataPath)) {
            throw 'The endpoint does not belong to the Nutrition local cluster.'
        }
        $exists = & $psql @arguments -d postgres -Atc "SELECT count(*) FROM pg_database WHERE datname='nutrition'"
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the database.' }
        if ($exists.Trim() -eq '0') {
            & $psql @arguments -d postgres -c 'CREATE DATABASE nutrition'
            if ($LASTEXITCODE -ne 0) { throw 'Database creation failed.' }
        }
        $tables = & $psql @arguments -d nutrition -Atc "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')"
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the schema.' }
        if ($tables.Trim() -eq '0') {
            & $psql @arguments -d nutrition -f $schemaPath
            if ($LASTEXITCODE -ne 0) { throw 'Schema initialization failed.' }
            # Supply the runtime password via stdin, never as a command-line argument or output.
            $roleSql = Get-Content -LiteralPath $rolePath -Raw
            "\set app_password '$($config.AppPassword)'`n$roleSql" | & $psql @arguments -d nutrition
            if ($LASTEXITCODE -ne 0) { throw 'Runtime role initialization failed.' }
        }
        $catalogExists = & $psql @arguments -d nutrition -Atc "SELECT count(*) FROM pg_tables WHERE schemaname='nutrition' AND tablename='catalog_packages'"
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the catalog governance schema.' }
        if ($catalogExists.Trim() -eq '0') {
            & $psql @arguments -d nutrition -f $catalogPath
            if ($LASTEXITCODE -ne 0) { throw 'Catalog governance migration failed.' }
        }
        & $psql @arguments -d nutrition -f $constraintPath
        if ($LASTEXITCODE -ne 0) { throw 'Catalog nutrient constraint migration failed.' }
        & $psql @arguments -d nutrition -f $citationPath
        if ($LASTEXITCODE -ne 0) { throw 'Recipe source citation migration failed.' }
        $env:PGPASSWORD = $config.AppPassword
        $verify = & $psql -X -h 127.0.0.1 -p $Port -U nutrition_app -d nutrition -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='nutrition'"
        if ($LASTEXITCODE -ne 0 -or $verify.Trim() -ne '10') { throw 'Nutrition schema or runtime access is incomplete. No existing data was reset.' }
        Write-Host "Nutrition PostgreSQL is running at 127.0.0.1:$Port (database nutrition, runtime nutrition_app)."
        Write-Host "Local configuration: $configPath"
        Write-Host 'The existing CareSitter database was not modified. Full schema and permission checks run at /health/ready.'
    } finally {
        if ($null -eq $previousPassword) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
        else { $env:PGPASSWORD = $previousPassword }
    }
} finally {
    $bootstrapLock.Dispose()
}
