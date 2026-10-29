[CmdletBinding()]
param([switch]$RealSchema)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifactRoot = Join-Path $repository 'backend/artifacts'
$suffix = [Guid]::NewGuid().ToString('N')
$databaseContainer = "caresitter-migrate-test-$suffix"
$state = Join-Path $artifactRoot "migrate-test-$suffix"
$sqlRoot = Join-Path $state 'sql'
$databaseStarted = $false
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-Fixture([string]$relativePath, [string]$content) {
    $path = Join-Path $sqlRoot $relativePath
    $parent = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [IO.File]::WriteAllText($path, $content.Replace("`r`n", "`n"), $utf8)
}

function Invoke-Docker([string[]]$arguments) {
    $null = & docker @arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed: $($arguments[0])" }
}

function Query([string]$statement, [string]$database = 'fixture') {
    $answer = & docker exec $databaseContainer psql -U postgres -d $database -At -v ON_ERROR_STOP=1 -c $statement
    if ($LASTEXITCODE -ne 0) { throw 'Fixture database query failed.' }
    return ($answer | Out-String).Trim()
}

function Run-Migration([string]$database = 'fixture', [bool]$allowDestructive = $false,
    [bool]$expectFailure = $false) {
    $allow = if ($allowDestructive) { 'true' } else { 'false' }
    $ErrorActionPreference = 'Continue'
    try {
        $output = & docker exec -e PGUSER=postgres -e "PGDATABASE=$database" -e "ALLOW_DESTRUCTIVE_MIGRATIONS=$allow" `
            $databaseContainer sh /migrate.sh 2>&1
    }
    finally { $ErrorActionPreference = 'Stop' }
    if (($LASTEXITCODE -ne 0) -ne $expectFailure) {
        throw "Migration exit status did not match expectation (failure expected: $expectFailure). $($output | Select-Object -Last 5 | Out-String)"
    }
}

try {
    New-Item -ItemType Directory -Path $sqlRoot -Force | Out-Null
    Write-Fixture '00-init.sql' @'
\ir modules/shared/00-foundation.sql
\ir modules/shared/09-seed.sql
\ir modules/people/19-drop-caregiver-availability.sql
\ir modules/people/21-drop-caregiver-hourly-rate.sql
'@
    Write-Fixture 'modules/shared/00-foundation.sql' @'
CREATE SCHEMA people;
CREATE TABLE people.caregiver_availability(id integer PRIMARY KEY);
CREATE TABLE people.caregiver_profiles(id integer PRIMARY KEY, hourly_rate_expected integer);
'@
    Write-Fixture 'modules/shared/09-seed.sql' "CREATE TABLE public.demo_account(id integer);`n"
    Write-Fixture 'modules/people/19-drop-caregiver-availability.sql' "DROP TABLE people.caregiver_availability;`n"
    Write-Fixture 'modules/people/21-drop-caregiver-hourly-rate.sql' "ALTER TABLE people.caregiver_profiles DROP COLUMN hourly_rate_expected;`n"

    $password = 'fixture-' + [Guid]::NewGuid().ToString('N')
    Invoke-Docker @('run', '-d', '--name', $databaseContainer, '-e', "POSTGRES_PASSWORD=$password",
        '-e', 'POSTGRES_DB=fixture', 'postgis/postgis:16-3.4') | Out-Null
    $databaseStarted = $true
    $ready = $false
    foreach ($attempt in 1..30) {
        $pidOne = (& docker exec $databaseContainer cat /proc/1/comm 2>$null | Out-String).Trim()
        if ($pidOne -eq 'postgres') {
            & docker exec $databaseContainer pg_isready -U postgres -d fixture *> $null
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'Fixture PostgreSQL did not become ready.' }
    Invoke-Docker @('cp', $sqlRoot, "${databaseContainer}:/sql")
    $runner = Join-Path $state 'migrate.sh'
    [IO.File]::WriteAllText($runner,
        ([IO.File]::ReadAllText((Join-Path $repository 'deploy/migrate.sh'))).Replace("`r`n", "`n"), $utf8)
    Invoke-Docker @('cp', $runner, "${databaseContainer}:/migrate.sh")

    Run-Migration
    if ((Query 'SELECT count(*) FROM public.schema_migrations') -ne '3') {
        throw 'Fresh DB did not record one checksum per schema migration.'
    }
    if ((Query "SELECT to_regclass('public.demo_account') IS NULL") -ne 't') {
        throw 'Demo seed was applied to the fresh DB.'
    }
    if ((Query "SELECT to_regclass('people.caregiver_availability') IS NULL") -ne 't') {
        throw 'Fresh DB did not reach final schema.'
    }
    Write-Output 'PASS: fresh DB applies nested SQL, skips demo seed and records per-file checksums.'

    Run-Migration
    if ((Query 'SELECT count(*) FROM public.schema_migrations') -ne '3') {
        throw 'A replay changed the fresh DB ledger.'
    }

    Invoke-Docker @('exec', $databaseContainer, 'createdb', '-U', 'postgres', 'fixture_old')
    Invoke-Docker @('exec', $databaseContainer, 'psql', '-U', 'postgres', '-d', 'fixture_old',
        '-v', 'ON_ERROR_STOP=1', '-f', '/sql/modules/shared/00-foundation.sql')
    $foundationHash = (Get-FileHash -LiteralPath (Join-Path $sqlRoot 'modules/shared/00-foundation.sql') -Algorithm SHA256).Hash.ToLowerInvariant()
    $baselineSql = "CREATE TABLE public.schema_migrations (filename text PRIMARY KEY, checksum_sha256 varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()); INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('00-foundation.sql', '$foundationHash');"
    Invoke-Docker @('exec', $databaseContainer, 'psql', '-U', 'postgres', '-d', 'fixture_old',
        '-v', 'ON_ERROR_STOP=1', '-c', $baselineSql)
    Run-Migration -database fixture_old -expectFailure $true
    if ((Query "SELECT to_regclass('people.caregiver_availability') IS NOT NULL" 'fixture_old') -ne 't' -or
        (Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_old') -ne '1') {
        throw 'Destructive guard did not preserve the old DB.'
    }
    Run-Migration -database fixture_old -allowDestructive $true
    if ((Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_old') -ne '3' -or
        (Query "SELECT to_regclass('public.demo_account') IS NULL" 'fixture_old') -ne 't') {
        throw 'Old DB upgrade did not reach the expected schema without demo seed.'
    }
    Write-Output 'PASS: old DB guard blocks DROP; explicit approval upgrades and records nested files.'

    Invoke-Docker @('exec', $databaseContainer, 'createdb', '-U', 'postgres', 'fixture_legacy')
    Invoke-Docker @('exec', $databaseContainer, 'psql', '-U', 'postgres', '-d', 'fixture_legacy',
        '-v', 'ON_ERROR_STOP=1', '-f', '/sql/modules/shared/00-foundation.sql') | Out-Null
    $legacySql = "CREATE TABLE public.schema_migrations (filename text PRIMARY KEY, checksum_sha256 varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()); INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('00-init.sql', repeat('a', 64));"
    Invoke-Docker @('exec', $databaseContainer, 'psql', '-U', 'postgres', '-d', 'fixture_legacy',
        '-v', 'ON_ERROR_STOP=1', '-c', $legacySql) | Out-Null
    Run-Migration -database fixture_legacy -expectFailure $true
    if ((Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_legacy') -ne '1') {
        throw 'Legacy manifest-only ledger was changed without an audited baseline.'
    }
    Write-Output 'PASS: legacy manifest-only ledger is blocked pending an audited baseline.'

    Write-Fixture 'modules/shared/23-retry.sql' "CREATE TABLE public.retry_checkpoint(id integer);`nSELECT 1/0;`n"
    [IO.File]::AppendAllText((Join-Path $sqlRoot '00-init.sql'),
        "`n\ir modules/shared/23-retry.sql`n", $utf8)
    Invoke-Docker @('cp', (Join-Path $sqlRoot '00-init.sql'), "${databaseContainer}:/sql/00-init.sql")
    Invoke-Docker @('cp', (Join-Path $sqlRoot 'modules/shared/23-retry.sql'),
        "${databaseContainer}:/sql/modules/shared/23-retry.sql")
    Run-Migration -database fixture_old -expectFailure $true
    if ((Query "SELECT to_regclass('public.retry_checkpoint') IS NULL" 'fixture_old') -ne 't' -or
        (Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_old') -ne '3') {
        throw 'Failed migration left DDL or a ledger entry behind.'
    }
    Write-Fixture 'modules/shared/23-retry.sql' "CREATE TABLE public.retry_checkpoint(id integer);`n"
    Invoke-Docker @('cp', (Join-Path $sqlRoot 'modules/shared/23-retry.sql'),
        "${databaseContainer}:/sql/modules/shared/23-retry.sql")
    Run-Migration -database fixture_old
    Run-Migration -database fixture_old
    if ((Query "SELECT to_regclass('public.retry_checkpoint') IS NOT NULL" 'fixture_old') -ne 't' -or
        (Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_old') -ne '4') {
        throw 'Fixed migration did not apply once after retry.'
    }
    Write-Output 'PASS: failed migration rolls back; corrected file applies once and replay is safe.'

    if ($RealSchema) {
        Invoke-Docker @('exec', $databaseContainer, 'createdb', '-U', 'postgres', 'fixture_real')
        Invoke-Docker @('cp', (Join-Path $repository 'backend/init-db'), "${databaseContainer}:/real-sql")
        $ErrorActionPreference = 'Continue'
        try {
            $realOutput = & docker exec -e PGUSER=postgres -e PGDATABASE=fixture_real `
                -e CARESITTER_SQL_DIRECTORY=/real-sql $databaseContainer sh /migrate.sh 2>&1
        }
        finally { $ErrorActionPreference = 'Stop' }
        if ($LASTEXITCODE -ne 0) {
            throw "Real SQL bootstrap failed: $($realOutput | Select-Object -Last 8 | Out-String)"
        }
        if ((Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_real') -ne '54' -or
            (Query 'SELECT count(*) FROM identity.users' 'fixture_real') -ne '0') {
            throw 'Real SQL bootstrap ledger or demo-account exclusion is incorrect.'
        }
        Write-Output 'PASS: all 54 real schema migrations apply to a disposable database without demo accounts.'

        Invoke-Docker @('exec', $databaseContainer, 'createdb', '-U', 'postgres', 'fixture_bootstrap')
        Invoke-Docker @('exec', '-e', 'PGOPTIONS=-c client_min_messages=warning', $databaseContainer,
            'psql', '-X', '-U', 'postgres', '-d', 'fixture_bootstrap',
            '-v', 'ON_ERROR_STOP=1', '-f', '/real-sql/00-init.sql') | Out-Null
        $manifestHash = (Get-FileHash -LiteralPath (Join-Path $repository 'backend/init-db/00-init.sql') -Algorithm SHA256).Hash.ToLowerInvariant()
        $oldLedger = "CREATE TABLE public.schema_migrations (filename text PRIMARY KEY, checksum_sha256 varchar(64) NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()); INSERT INTO public.schema_migrations(filename, checksum_sha256) VALUES ('00-init.sql', '$manifestHash');"
        Invoke-Docker @('exec', $databaseContainer, 'psql', '-U', 'postgres', '-d', 'fixture_bootstrap',
            '-v', 'ON_ERROR_STOP=1', '-c', $oldLedger) | Out-Null
        $baseline = Join-Path $state 'baseline-legacy.sh'
        [IO.File]::WriteAllText($baseline,
            ([IO.File]::ReadAllText((Join-Path $repository 'deploy/baseline-legacy.sh'))).Replace("`r`n", "`n"), $utf8)
        Invoke-Docker @('cp', $baseline, "${databaseContainer}:/baseline-legacy.sh")
        $ErrorActionPreference = 'Continue'
        try {
            $baselineOutput = & docker exec -e PGUSER=postgres -e PGDATABASE=fixture_bootstrap `
                -e CARESITTER_SQL_DIRECTORY=/real-sql -e LEGACY_BASELINE_APPROVED=true `
                -e BACKUP_RESTORE_VERIFIED=true -e "LEGACY_BASELINE_EXPECTED_SHA256=$manifestHash" `
                $databaseContainer sh /baseline-legacy.sh 2>&1
        }
        finally { $ErrorActionPreference = 'Stop' }
        if ($LASTEXITCODE -ne 0) {
            throw "Audited legacy baseline failed: $($baselineOutput | Select-Object -Last 8 | Out-String)"
        }
        $ErrorActionPreference = 'Continue'
        try {
            $replayOutput = & docker exec -e PGUSER=postgres -e PGDATABASE=fixture_bootstrap `
                -e CARESITTER_SQL_DIRECTORY=/real-sql $databaseContainer sh /migrate.sh 2>&1
        }
        finally { $ErrorActionPreference = 'Stop' }
        if ($LASTEXITCODE -ne 0 -or
            (Query 'SELECT count(*) FROM public.schema_migrations' 'fixture_bootstrap') -ne '54' -or
            (Query "SELECT count(*) FROM public.schema_migrations WHERE filename='00-init.sql'" 'fixture_bootstrap') -ne '0') {
            throw "Legacy DB could not replay after baseline: $($replayOutput | Select-Object -Last 8 | Out-String)"
        }
        Write-Output 'PASS: real legacy bootstrap receives an explicit baseline and safely replays.'
    }
}
finally {
    if ($databaseStarted) { & docker rm -f $databaseContainer *> $null }
    if (Test-Path -LiteralPath $state) {
        $resolvedState = [IO.Path]::GetFullPath($state)
        $resolvedRoot = [IO.Path]::GetFullPath($artifactRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) +
            [IO.Path]::DirectorySeparatorChar
        if (-not $resolvedState.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a fixture outside backend/artifacts.'
        }
        Remove-Item -LiteralPath $resolvedState -Recurse -Force
    }
}
