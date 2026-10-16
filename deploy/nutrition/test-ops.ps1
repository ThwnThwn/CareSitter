param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$Bash = 'C:\Program Files\Git\bin\bash.exe',
    [Parameter(Mandatory)][string]$AgeBin
)
$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$state = Join-Path $repository ('backend/artifacts/nutrition-staging-20261013/ops-' + [Guid]::NewGuid().ToString('N'))
$data = Join-Path $state 'data'
New-Item -ItemType Directory -Path $state | Out-Null
$password = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
$passwordFile = Join-Path $state 'bootstrap-password.tmp'
[IO.File]::WriteAllText($passwordFile, $password)
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
$variables = @('PATH','TMPDIR','PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGPASSWORD_FILE',
    'NUTRITION_APP_PASSWORD_FILE','NUTRITION_SQL_DIRECTORY','BACKUP_DIRECTORY','BACKUP_RECIPIENT_FILE',
    'BACKUP_IDENTITY_FILE','CARESITTER_TEST_ADMIN_CONNECTION')
$previous = @{}
foreach ($name in $variables) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$started = $false
$originalLocation = Get-Location
function Run-Shell([string]$script, [string[]]$parameters = @(), [bool]$shouldFail = $false) {
    $log = Join-Path $state ('shell-' + [Guid]::NewGuid().ToString('N') + '.log')
    $parameters = @($parameters | ForEach-Object { $_.Replace('\','/') })
    & $Bash --noprofile --norc $script @parameters *> $log
    $code = $LASTEXITCODE
    if (($shouldFail -and $code -eq 0) -or (!$shouldFail -and $code -ne 0)) {
        throw "Unexpected shell exit code ($code); inspect protected local test output in $state."
    }
}
function Query([string]$sql, [string]$database = $env:PGDATABASE) {
    $result = & (Join-Path $PostgresBin 'psql.exe') -X -q -t -A -v ON_ERROR_STOP=1 --dbname=$database -c $sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Isolated fixture SQL query failed.' }
    return ($result -join "`n").Trim()
}
try {
    Set-Location $repository
    $env:PATH = "$PostgresBin;$AgeBin;$env:PATH"
    $env:TMPDIR = $state.Replace('\','/')
    & (Join-Path $PostgresBin 'initdb.exe') -D $data -U ops_test -A scram-sha-256 --pwfile=$passwordFile --encoding=UTF8 --locale=C *> (Join-Path $state 'initdb.log')
    if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL initialization failed.' }
    $startup = Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D', $data, '-l', (Join-Path $state 'server.log'), '-o', ('"-h 127.0.0.1 -p ' + $port + '"'), '-w', 'start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $state 'startup.log') -RedirectStandardError (Join-Path $state 'startup-error.log')
    if (!$startup.WaitForExit(30000) -or $startup.ExitCode -ne 0) { throw 'Isolated PostgreSQL startup failed.' }
    $started = $true
    $env:PGHOST = '127.0.0.1'; $env:PGPORT = $port; $env:PGUSER = 'ops_test'; $env:PGPASSWORD = $password
    & (Join-Path $PostgresBin 'createdb.exe') nutrition
    if ($LASTEXITCODE -ne 0) { throw 'Isolated nutrition DB creation failed.' }
    $env:PGDATABASE = 'nutrition'
    $secrets = Join-Path $state 'secrets'
    $recovery = Join-Path $state 'recovery'
    Run-Shell 'deploy/nutrition/prepare-secrets.sh' @($secrets, $recovery)
    $secretHashes = Get-ChildItem -LiteralPath $secrets -File | Get-FileHash -Algorithm SHA256
    Run-Shell 'deploy/nutrition/prepare-secrets.sh' @($secrets, $recovery)
    foreach ($file in $secretHashes) {
        if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $file.Hash) { throw 'Preparation replaced an existing secret.' }
    }
    Write-Output 'PASS: secret preparation preserves existing credentials/certificates.'
    Run-Shell 'deploy/nutrition/renew-certificates.sh' @($secrets)
    foreach ($file in $secretHashes | Where-Object { [IO.Path]::GetExtension($_.Path) -ne '.pfx' }) {
        if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $file.Hash) { throw 'Leaf renewal replaced CA or credentials.' }
    }
    foreach ($file in $secretHashes | Where-Object { [IO.Path]::GetExtension($_.Path) -eq '.pfx' }) {
        if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -eq $file.Hash) { throw 'Leaf certificate was not renewed.' }
    }
    Write-Output 'PASS: leaf certificate renewal preserves CA, passwords and internal keys.'
    $env:PGPASSWORD_FILE = $passwordFile.Replace('\','/')
    $env:NUTRITION_APP_PASSWORD_FILE = (Join-Path $secrets 'db-app-password').Replace('\','/')
    $env:NUTRITION_SQL_DIRECTORY = (Join-Path $repository 'backend/init-db/nutrition-service').Replace('\','/')
    Run-Shell 'deploy/nutrition/migrate.sh'
    Run-Shell 'deploy/nutrition/migrate.sh'
    if ((Query 'SELECT count(*) FROM public.nutrition_schema_migrations') -ne '5') { throw 'Migration replay did not preserve its ledger.' }
    Write-Output 'PASS: initial migration and replay.'

    $sqlFixture = Join-Path $state 'sql'
    New-Item -ItemType Directory -Path $sqlFixture | Out-Null
    Copy-Item -LiteralPath (Join-Path $env:NUTRITION_SQL_DIRECTORY '01-nutrition-workflow.sql') -Destination $sqlFixture
    Copy-Item -LiteralPath (Join-Path $env:NUTRITION_SQL_DIRECTORY '02-runtime-role.sql') -Destination $sqlFixture
    Copy-Item -LiteralPath (Join-Path $env:NUTRITION_SQL_DIRECTORY '03-catalog-governance.sql') -Destination $sqlFixture
    Copy-Item -LiteralPath (Join-Path $env:NUTRITION_SQL_DIRECTORY '04-catalog-nutrient-constraints.sql') -Destination $sqlFixture
    Copy-Item -LiteralPath (Join-Path $env:NUTRITION_SQL_DIRECTORY '05-recipe-source-citations.sql') -Destination $sqlFixture
    $env:NUTRITION_SQL_DIRECTORY = $sqlFixture.Replace('\','/')
    foreach ($file in Get-ChildItem -LiteralPath $sqlFixture -Filter '*.sql') {
        [IO.File]::WriteAllText($file.FullName, [IO.File]::ReadAllText($file.FullName).Replace("`r`n","`n"))
    }
    Run-Shell 'deploy/nutrition/migrate.sh'
    Write-Output 'PASS: LF/CRLF checkout conversion preserves migration checksums.'
    $changed = Join-Path $sqlFixture '01-nutrition-workflow.sql'
    [IO.File]::AppendAllText($changed, "`n-- Changed fixture checksum.`n")
    Run-Shell 'deploy/nutrition/migrate.sh' @() $true
    Copy-Item -LiteralPath (Join-Path $repository 'backend/init-db/nutrition-service/01-nutrition-workflow.sql') -Destination $changed -Force
    Write-Output 'PASS: changed applied migration rejected.'
    $failing = Join-Path $sqlFixture '06-transaction-test.sql'
    [IO.File]::WriteAllText($failing, "CREATE TABLE nutrition.rollback_probe(id integer); SELECT 1/0;`n")
    Run-Shell 'deploy/nutrition/migrate.sh' @() $true
    if ((Query "SELECT to_regclass('nutrition.rollback_probe') IS NULL") -ne 't') { throw 'Failed migration left a partially created table.' }
    if ((Query 'SELECT count(*) FROM public.nutrition_schema_migrations') -ne '5') { throw 'Failed migration was recorded as applied.' }
    Remove-Item -LiteralPath $failing
    Write-Output 'PASS: failed migration and its ledger insertion roll back together.'
    $race = Join-Path $sqlFixture '06-concurrent-test.sql'
    [IO.File]::WriteAllText($race, "SELECT pg_sleep(1); CREATE TABLE public.concurrent_probe(id integer);`n")
    $script = 'deploy/nutrition/migrate.sh'
    $processes = 1..2 | ForEach-Object {
        Start-Process -FilePath $Bash -ArgumentList @('--noprofile','--norc',$script) -WorkingDirectory $repository -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $state "race-$_.log") -RedirectStandardError (Join-Path $state "race-$_.error.log")
    }
    foreach ($process in $processes) { if (!$process.WaitForExit(30000) -or $process.ExitCode -ne 0) { throw 'Concurrent migration failed.' } }
    if ((Query 'SELECT count(*) FROM public.nutrition_schema_migrations') -ne '6') { throw 'Concurrent migration ledger mismatch.' }
    Write-Output 'PASS: concurrent migration runners serialize and replay safely.'

    $owner = [Guid]::NewGuid().ToString(); $beneficiary = [Guid]::NewGuid().ToString()
    Query "INSERT INTO nutrition.preferences(beneficiary_id,customer_id,payload) VALUES ('$beneficiary','$owner',jsonb_build_object('test',true));" | Out-Null
    $env:BACKUP_DIRECTORY = (Join-Path $state 'backups').Replace('\','/')
    $env:BACKUP_RECIPIENT_FILE = (Join-Path $secrets 'backup-recipient').Replace('\','/')
    $env:BACKUP_IDENTITY_FILE = (Join-Path $recovery 'age-identity').Replace('\','/')
    Run-Shell 'deploy/nutrition/backup.sh'
    $archive = Get-ChildItem -LiteralPath $env:BACKUP_DIRECTORY -Filter '*.dump.age' | Select-Object -First 1
    if (!$archive -or (Get-ChildItem -LiteralPath $env:BACKUP_DIRECTORY -Filter '*.dump').Count) { throw 'Backup left plaintext in its output directory.' }
    Run-Shell 'deploy/nutrition/restore-check.sh' @($archive.FullName)
    $restoredDump = Join-Path $state 'restore-assert.dump'
    $restoreDatabase = 'nutrition_restore_' + [Guid]::NewGuid().ToString('N')
    & (Join-Path $AgeBin 'age.exe') -d -i $env:BACKUP_IDENTITY_FILE -o $restoredDump $archive.FullName 2> (Join-Path $state 'decrypt-error.log')
    if ($LASTEXITCODE -ne 0) { throw 'Independent backup decryption failed.' }
    & (Join-Path $PostgresBin 'createdb.exe') $restoreDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Independent scratch DB creation failed.' }
    try {
        & (Join-Path $PostgresBin 'pg_restore.exe') --exit-on-error --single-transaction --no-owner --dbname=$restoreDatabase $restoredDump *> (Join-Path $state 'restore-assert.log')
        if ($LASTEXITCODE -ne 0) { throw 'Independent scratch restore failed.' }
        if ((Query "SELECT (payload->>'test')::boolean FROM nutrition.preferences WHERE customer_id='$owner' AND beneficiary_id='$beneficiary'" $restoreDatabase) -ne 't') { throw 'Encrypted backup lost fixture data.' }
        $owned = "BEGIN; SET LOCAL ROLE nutrition_app; SET LOCAL app.current_user_id='$owner'; SELECT count(*) FROM nutrition.preferences; ROLLBACK;"
        if ((Query $owned $restoreDatabase) -ne '1') { throw 'Restored owner access is broken.' }
        $otherOwner = [Guid]::NewGuid().ToString()
        $foreign = "BEGIN; SET LOCAL ROLE nutrition_app; SET LOCAL app.current_user_id='$otherOwner'; SELECT count(*) FROM nutrition.preferences; ROLLBACK;"
        if ((Query $foreign $restoreDatabase) -ne '0') { throw 'Restored RLS leaked another owner data.' }
        Write-Output 'PASS: restored row content and owner/foreign-owner access verified independently.'
    }
    finally {
        & (Join-Path $PostgresBin 'dropdb.exe') $restoreDatabase
        Remove-Item -LiteralPath $restoredDump -ErrorAction SilentlyContinue
    }
    if ((Query "SELECT count(*) FROM pg_database WHERE datname LIKE 'nutrition_restore_%'") -ne '0') { throw 'Restore rehearsal left a scratch database.' }
    if ((Query 'SELECT count(*) FROM nutrition.preferences') -ne '1') { throw 'Restore rehearsal changed source data.' }
    Write-Output 'PASS: encrypted backup restores with schema, ACL and RLS; source data remains intact.'
    $checksumFile = $archive.FullName + '.sha256'
    $checksumText = [IO.File]::ReadAllText($checksumFile)
    [IO.File]::WriteAllText($checksumFile, ('0' * 64) + '  ' + $archive.Name + "`n")
    Run-Shell 'deploy/nutrition/restore-check.sh' @($archive.FullName) $true
    [IO.File]::WriteAllText($checksumFile, $checksumText)
    Write-Output 'PASS: corrupted encrypted backup rejected before restore.'

    $env:CARESITTER_TEST_ADMIN_CONNECTION = "Host=127.0.0.1;Port=$port;Database=postgres;Username=ops_test;Password=$password"
    & dotnet test backend/services/nutrition/tests/CareSitter.Nutrition.Tests/CareSitter.Nutrition.Tests.csproj --no-restore --verbosity quiet --logger 'trx;LogFileName=nutrition-postgres.trx' --results-directory (Join-Path $state 'results') *> (Join-Path $state 'nutrition-tests.log')
    if ($LASTEXITCODE -ne 0) { throw "Nutrition regression failed; inspect $state." }
    Get-Content (Join-Path $state 'nutrition-tests.log') -Tail 2
    Write-Output "Ops test artifacts: $state"
}
finally {
    if ($started) { & (Join-Path $PostgresBin 'pg_ctl.exe') -D $data -w stop *> (Join-Path $state 'shutdown.log') }
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    Remove-Item -LiteralPath $passwordFile -ErrorAction SilentlyContinue
    Set-Location $originalLocation
}
