[CmdletBinding()]
param(
    [ValidateRange(1, 5)]
    [int]$Repeat = 2,
    [switch]$SkipFrontend,
    [ValidateRange(1024, 65000)]
    [int]$ApiPort = 5033,
    [string]$TestPassword = 'CareSitter123!',
    [string]$ArtifactsDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendRoot
$composeFile = Join-Path $backendRoot 'docker-compose.yml'
$migrationDirectory = Join-Path $backendRoot 'init-db'
$solution = Join-Path $backendRoot 'CareSitter.sln'
$apiHostDirectory = Join-Path (Join-Path $backendRoot 'caresitter-be') 'ApiHost'
$apiProject = Join-Path $apiHostDirectory 'CareSitter.ApiHost.csproj'
$smokeScript = Join-Path $PSScriptRoot 'smoke-test.ps1'
$updateDbScript = Join-Path $PSScriptRoot 'update-db.ps1'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'

if ([string]::IsNullOrWhiteSpace($ArtifactsDirectory)) {
    $ArtifactsDirectory = Join-Path $backendRoot "artifacts\phase7\$runId"
}
$ArtifactsDirectory = [System.IO.Path]::GetFullPath($ArtifactsDirectory)
New-Item -ItemType Directory -Force -Path $ArtifactsDirectory | Out-Null

$temporaryContainers = [System.Collections.Generic.List[string]]::new()
$temporaryDirectories = [System.Collections.Generic.List[string]]::new()
$runSummaries = [System.Collections.Generic.List[object]]::new()
$apiProcess = $null

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Description
    )

    Write-Host "==> $Description"
    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments 2>&1 | Tee-Object -FilePath $LogPath
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode. See $LogPath"
    }
}

function Get-DockerLogs {
    param([Parameter(Mandatory)][string]$ContainerName)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        return ((& docker logs $ContainerName 2>&1) -join [Environment]::NewLine)
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Wait-ContainerHealthy {
    param(
        [Parameter(Mandatory)][string]$ContainerName,
        [int]$Attempts = 60
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $state = & docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' $ContainerName 2>$null
        if ($LASTEXITCODE -eq 0 -and $state -eq 'running|healthy') {
            return
        }
        if ($state -like 'exited*' -or $state -like 'dead*') {
            $logs = Get-DockerLogs -ContainerName $ContainerName
            throw "Container '$ContainerName' stopped before becoming healthy.`n$logs"
        }
        Start-Sleep -Seconds 2
    }

    $logs = Get-DockerLogs -ContainerName $ContainerName
    throw "Container '$ContainerName' did not become healthy.`n$logs"
}

function Get-ContainerEnvironment {
    param([Parameter(Mandatory)][string]$ContainerName)

    $container = (& docker inspect $ContainerName | ConvertFrom-Json)[0]
    if ($LASTEXITCODE -ne 0 -or $null -eq $container) {
        throw "Unable to inspect container '$ContainerName'."
    }

    $values = @{}
    foreach ($entry in $container.Config.Env) {
        $parts = $entry -split '=', 2
        if ($parts.Count -eq 2) {
            $values[$parts[0]] = $parts[1]
        }
    }
    return $values
}

function Get-PublishedPort {
    param(
        [Parameter(Mandatory)][string]$ContainerName,
        [Parameter(Mandatory)][string]$ContainerPort
    )

    $mapping = @(& docker port $ContainerName $ContainerPort 2>$null) | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or $mapping -notmatch ':(?<port>\d+)$') {
        throw "Unable to resolve the published port for $ContainerName/$ContainerPort."
    }
    return [int]$Matches.port
}

function Invoke-PsqlScalar {
    param(
        [Parameter(Mandatory)][string]$ContainerName,
        [Parameter(Mandatory)][string]$DatabaseUser,
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$Sql
    )

    $rows = @(& docker exec $ContainerName psql `
        -v ON_ERROR_STOP=1 `
        -U $DatabaseUser `
        -d $DatabaseName `
        -Atc $Sql 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Database verification failed in '$ContainerName': $($rows -join [Environment]::NewLine)"
    }
    return ($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1).Trim()
}

function Start-TemporaryPostgres {
    param(
        [Parameter(Mandatory)][string]$NameSuffix,
        [Parameter(Mandatory)][string]$MigrationsPath
    )

    $containerName = "caresitter-phase7-$NameSuffix-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $databaseUser = 'phase7'
    $databasePassword = 'phase7-local-only'
    $databaseName = 'caresitter'
    $mountSource = [System.IO.Path]::GetFullPath($MigrationsPath)

    $containerId = & docker run `
        --detach `
        --rm `
        --name $containerName `
        --env "POSTGRES_DB=$databaseName" `
        --env "POSTGRES_USER=$databaseUser" `
        --env "POSTGRES_PASSWORD=$databasePassword" `
        --publish '127.0.0.1::5432' `
        --mount "type=bind,source=$mountSource,target=/docker-entrypoint-initdb.d,readonly" `
        --health-cmd "pg_isready -U $databaseUser -d $databaseName" `
        --health-interval 2s `
        --health-timeout 3s `
        --health-retries 45 `
        postgis/postgis:16-3.4
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
        throw "Unable to start temporary PostgreSQL container '$containerName'."
    }

    $temporaryContainers.Add($containerName)
    Wait-ContainerHealthy -ContainerName $containerName

    $initialized = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        $containerLogs = Get-DockerLogs -ContainerName $containerName
        if ($containerLogs -match 'PostgreSQL init process complete') {
            $initialized = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $initialized) {
        throw "PostgreSQL entrypoint did not finish migrations in '$containerName'.`n$containerLogs"
    }

    Wait-ContainerHealthy -ContainerName $containerName
    $ready = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $relation = & docker exec $containerName psql `
            -U $databaseUser -d $databaseName -Atc "SELECT to_regclass('identity.users');" 2>$null
        if ($LASTEXITCODE -eq 0 -and $relation -eq 'identity.users') {
            $ready = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        $logs = Get-DockerLogs -ContainerName $containerName
        throw "Migrations did not finish in '$containerName'.`n$logs"
    }

    return [pscustomobject]@{
        Name = $containerName
        User = $databaseUser
        Password = $databasePassword
        Database = $databaseName
        Port = Get-PublishedPort -ContainerName $containerName -ContainerPort '5432/tcp'
    }
}

function Get-DataSignature {
    param([Parameter(Mandatory)]$Database)

    $sql = @"
SELECT json_build_object(
  'users', (SELECT count(*) FROM identity.users),
  'services', (SELECT count(*) FROM catalog.service_types),
  'addresses', (SELECT count(*) FROM catalog.addresses),
  'beneficiaries', (SELECT count(*) FROM people.beneficiaries),
  'caregivers', (SELECT count(*) FROM people.caregiver_profiles),
  'wallets', (SELECT count(*) FROM payments.wallet_accounts),
  'bookings', (SELECT count(*) FROM booking.bookings),
  'disputes', (SELECT count(*) FROM support.disputes)
)::text;
"@
    return Invoke-PsqlScalar `
        -ContainerName $Database.Name `
        -DatabaseUser $Database.User `
        -DatabaseName $Database.Database `
        -Sql $sql
}

function Initialize-SeedAccounts {
    param([Parameter(Mandatory)]$Database)

    $escapedPassword = $TestPassword.Replace("'", "''")
    $sql = @"
UPDATE identity.users
SET password_hash = crypt('$escapedPassword', gen_salt('bf', 12))
WHERE id IN (
  'a0000000-0000-0000-0000-0000000000a1',
  'a0000000-0000-0000-0000-0000000000c1',
  'a0000000-0000-0000-0000-0000000000e1',
  'a0000000-0000-0000-0000-0000000000e3',
  'a0000000-0000-0000-0000-0000000000e5',
  'a0000000-0000-0000-0000-0000000000e7'
);
SELECT count(*)
FROM identity.users
WHERE id IN (
  'a0000000-0000-0000-0000-0000000000a1',
  'a0000000-0000-0000-0000-0000000000c1',
  'a0000000-0000-0000-0000-0000000000e1',
  'a0000000-0000-0000-0000-0000000000e3',
  'a0000000-0000-0000-0000-0000000000e5',
  'a0000000-0000-0000-0000-0000000000e7'
)
AND crypt('$escapedPassword', password_hash) = password_hash;
"@
    $verified = Invoke-PsqlScalar `
        -ContainerName $Database.Name `
        -DatabaseUser $Database.User `
        -DatabaseName $Database.Database `
        -Sql $sql
    if ($verified -ne '6') {
        throw "Expected six usable seed accounts, but verified $verified."
    }
}

function Assert-Phase7Schema {
    param([Parameter(Mandatory)]$Database)

    $sql = @"
SELECT (
  to_regclass('identity.users') IS NOT NULL
  AND to_regclass('catalog.service_types') IS NOT NULL
  AND to_regclass('booking.bookings') IS NOT NULL
  AND to_regclass('payments.ledger_entries') IS NOT NULL
  AND to_regclass('support.disputes') IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'booking' AND table_name = 'bookings'
      AND column_name = 'dispute_window_hours')
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'identity' AND table_name = 'users'
      AND column_name = 'avatar_url')
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'identity' AND table_name = 'users'
      AND column_name = 'notification_prefs')
  AND to_regprocedure('booking.prevent_active_beneficiary_booking_overlap()') IS NOT NULL
)::text;
"@
    $valid = Invoke-PsqlScalar `
        -ContainerName $Database.Name `
        -DatabaseUser $Database.User `
        -DatabaseName $Database.Database `
        -Sql $sql
    if ($valid -ne 'true' -and $valid -ne 't') {
        throw 'The clean database does not contain all Phase 7/8 schema objects.'
    }
}

function Test-LegacyUpgrade {
    param([Parameter(Mandatory)][int]$RunNumber)

    $legacyDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "caresitter-phase7-legacy-$runId-$RunNumber"
    New-Item -ItemType Directory -Force -Path $legacyDirectory | Out-Null
    $temporaryDirectories.Add($legacyDirectory)

    $allMigrations = Get-ChildItem -LiteralPath $migrationDirectory -File |
        Where-Object { $_.Name -match '^(?<number>\d{2})-.*\.sql$' } |
        Sort-Object Name
    foreach ($migration in $allMigrations) {
        if ([int]$migration.Name.Substring(0, 2) -le 25) {
            Copy-Item -LiteralPath $migration.FullName -Destination $legacyDirectory
        }
    }

    $legacyDatabase = Start-TemporaryPostgres `
        -NameSuffix "legacy-$RunNumber" `
        -MigrationsPath $legacyDirectory
    $before = Get-DataSignature -Database $legacyDatabase

    foreach ($migration in $allMigrations) {
        if ([int]$migration.Name.Substring(0, 2) -gt 25) {
            Copy-Item -LiteralPath $migration.FullName -Destination $legacyDirectory
        }
    }

    $null = & $updateDbScript `
        -From 26 `
        -AllowDestructive `
        -ContainerName $legacyDatabase.Name `
        -SkipStart `
        -MigrationPath $legacyDirectory

    $after = Get-DataSignature -Database $legacyDatabase
    if ($before -ne $after) {
        throw "Legacy upgrade changed protected seed-row counts. Before: $before; after: $after"
    }
    Assert-Phase7Schema -Database $legacyDatabase

    return [pscustomobject]@{
        Before = $before
        After = $after
    }
}

function Start-Phase7Api {
    param(
        [Parameter(Mandatory)]$Database,
        [Parameter(Mandatory)][int]$RedisPort,
        [Parameter(Mandatory)][string]$RedisPassword,
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][int]$RunNumber
    )

    $workingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "caresitter-phase7-api-$runId-$RunNumber"
    New-Item -ItemType Directory -Force -Path $workingDirectory | Out-Null
    $temporaryDirectories.Add($workingDirectory)

    $stdout = Join-Path $ArtifactsDirectory "api-run-$RunNumber.stdout.log"
    $stderr = Join-Path $ArtifactsDirectory "api-run-$RunNumber.stderr.log"
    $baseUrl = "http://127.0.0.1:$Port"
    $arguments = @(
        'run',
        '--project', $apiProject,
        '--configuration', 'Release',
        '--no-build',
        '--no-launch-profile',
        '--urls', $baseUrl,
        '--',
        '--environment=Development',
        "--ConnectionStrings:CareSitter=Host=127.0.0.1;Port=$($Database.Port);Database=$($Database.Database);Username=$($Database.User);Password=$($Database.Password)",
        "--Redis:ConnectionString=127.0.0.1:$RedisPort,password=$RedisPassword",
        '--Encryption:EncryptionKey=phase7-local-encryption-key-32-chars',
        '--Jwt:Issuer=CareSitter.Phase7',
        '--Jwt:Audience=CareSitter.Phase7',
        '--Jwt:SecretKey=phase7-local-jwt-secret-key-32-characters',
        '--Jwt:ExpiryMinutes=60',
        '--Jwt:RefreshTokenExpiryDays=7',
        '--Smtp:Host=smtp.gmail.com',
        '--Smtp:Port=587',
        '--Smtp:UserName=phase7@example.com',
        '--Smtp:Password=phase7-local-only',
        '--Smtp:FromName=CareSitterPhase7',
        '--Smtp:TimeoutSeconds=5',
        '--Payments:VNPay:PaymentTimeoutMinutes=15',
        '--Payments:VNPay:BookingPaymentDeadlineMinutes=30',
        '--Payments:VNPay:MaxReconciliationAttempts=3',
        '--Payments:VNPay:ReconciliationWindowMinutes=10',
        '--CheckIn:EarlyWindowMinutes=30',
        '--CheckIn:MaxDistanceMeters=250'
    )

    $startParameters = @{
        FilePath = 'dotnet'
        ArgumentList = $arguments
        WorkingDirectory = $workingDirectory
        RedirectStandardOutput = $stdout
        RedirectStandardError = $stderr
        PassThru = $true
    }
    if ($env:OS -eq 'Windows_NT') {
        $startParameters['WindowStyle'] = 'Hidden'
    }
    $process = Start-Process @startParameters

    for ($attempt = 1; $attempt -le 45; $attempt++) {
        if ($process.HasExited) {
            $out = Get-Content -Raw -LiteralPath $stdout -ErrorAction SilentlyContinue
            $err = Get-Content -Raw -LiteralPath $stderr -ErrorAction SilentlyContinue
            throw "API exited during startup.`n$out`n$err"
        }
        try {
            $response = Invoke-WebRequest -Uri "$baseUrl/health/live" -UseBasicParsing -TimeoutSec 3
            if ([int]$response.StatusCode -eq 200) {
                return [pscustomobject]@{
                    Process = $process
                    BaseUrl = $baseUrl
                }
            }
        }
        catch {
            Start-Sleep -Seconds 2
        }
    }

    throw "API did not become live at $baseUrl."
}

function Stop-Phase7Api {
    param($Process)

    if ($null -ne $Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force
        $Process.WaitForExit(10000) | Out-Null
    }
}

function Get-TestCounters {
    param([Parameter(Mandatory)][string]$ResultsDirectory)

    $files = @(Get-ChildItem -LiteralPath $ResultsDirectory -Recurse -Filter '*.trx')
    if ($files.Count -eq 0) {
        throw "No TRX test results were created in $ResultsDirectory."
    }

    $total = 0
    $passed = 0
    $failed = 0
    $notExecuted = 0
    foreach ($file in $files) {
        [xml]$trx = Get-Content -Raw -LiteralPath $file.FullName
        $counters = $trx.TestRun.ResultSummary.Counters
        $total += [int]$counters.total
        $passed += [int]$counters.passed
        $failed += [int]$counters.failed
        $notExecuted += [int]$counters.notExecuted
    }

    return [pscustomobject]@{
        Total = $total
        Passed = $passed
        Failed = $failed
        NotExecuted = $notExecuted
        Files = $files.Count
    }
}

try {
    foreach ($command in @('docker', 'dotnet')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Required command '$command' was not found."
        }
    }
    $flutterInfo = Get-Command 'flutter.bat' -ErrorAction SilentlyContinue
    if ($null -eq $flutterInfo) {
        $flutterInfo = Get-Command 'flutter' -ErrorAction SilentlyContinue
    }
    $flutterCommand = if ($null -eq $flutterInfo) { $null } else { $flutterInfo.Source }

    $npmInfo = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if ($null -eq $npmInfo) {
        $npmInfo = Get-Command 'npm' -ErrorAction SilentlyContinue
    }
    $npmCommand = if ($null -eq $npmInfo) { $null } else { $npmInfo.Source }
    if (-not $SkipFrontend -and
        ([string]::IsNullOrWhiteSpace($flutterCommand) -or [string]::IsNullOrWhiteSpace($npmCommand))) {
        throw 'Flutter and npm are required unless -SkipFrontend is used.'
    }

    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker daemon is not running.'
    }

    Write-Host 'Starting Docker Compose PostgreSQL and Redis...'
    & docker compose -f $composeFile up -d db redis
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to start Docker Compose services.'
    }
    Wait-ContainerHealthy -ContainerName 'caresitter-db'
    Wait-ContainerHealthy -ContainerName 'caresitter-redis'

    $redisEnvironment = Get-ContainerEnvironment -ContainerName 'caresitter-redis'
    $redisPassword = $redisEnvironment['REDIS_PASSWORD']
    if ([string]::IsNullOrWhiteSpace($redisPassword)) {
        $redisPassword = 'caresitter'
    }
    $redisPort = Get-PublishedPort -ContainerName 'caresitter-redis' -ContainerPort '6379/tcp'

    Invoke-CheckedCommand `
        -FilePath 'dotnet' `
        -Arguments @('restore', $solution, '--nologo') `
        -WorkingDirectory $repoRoot `
        -LogPath (Join-Path $ArtifactsDirectory 'dotnet-restore.log') `
        -Description 'Restore backend dependencies'
    Invoke-CheckedCommand `
        -FilePath 'dotnet' `
        -Arguments @('build', $solution, '--configuration', 'Release', '--no-restore', '--nologo') `
        -WorkingDirectory $repoRoot `
        -LogPath (Join-Path $ArtifactsDirectory 'dotnet-build.log') `
        -Description 'Build backend in Release mode'

    for ($run = 1; $run -le $Repeat; $run++) {
        Write-Host "`n========== PHASE 7 ACCEPTANCE $run/$Repeat =========="
        Wait-ContainerHealthy -ContainerName 'caresitter-db'
        Wait-ContainerHealthy -ContainerName 'caresitter-redis'

        $cleanDatabase = Start-TemporaryPostgres `
            -NameSuffix "clean-$run" `
            -MigrationsPath $migrationDirectory
        Assert-Phase7Schema -Database $cleanDatabase
        Initialize-SeedAccounts -Database $cleanDatabase
        $cleanSignature = Get-DataSignature -Database $cleanDatabase
        $legacyResult = Test-LegacyUpgrade -RunNumber $run

        $api = Start-Phase7Api `
            -Database $cleanDatabase `
            -RedisPort $redisPort `
            -RedisPassword $redisPassword `
            -Port ($ApiPort + $run - 1) `
            -RunNumber $run
        $apiProcess = $api.Process
        try {
            & $smokeScript `
                -BaseUrl $api.BaseUrl `
                -AdminEmail 'admin@caresitter.vn' `
                -CustomerEmail 'nguoithan@example.com' `
                -CaregiverEmail 'nguoicham@example.com' `
                -TestPassword $TestPassword
            if ($LASTEXITCODE -ne 0) {
                throw "Smoke test failed in acceptance run $run."
            }
        }
        finally {
            Stop-Phase7Api -Process $apiProcess
            $apiProcess = $null
        }

        $testResultsDirectory = Join-Path $ArtifactsDirectory "tests-run-$run"
        New-Item -ItemType Directory -Force -Path $testResultsDirectory | Out-Null
        $previousAdminConnection = $env:CARESITTER_TEST_ADMIN_CONNECTION
        $env:CARESITTER_TEST_ADMIN_CONNECTION =
            "Host=127.0.0.1;Port=$($cleanDatabase.Port);Database=postgres;Username=$($cleanDatabase.User);Password=$($cleanDatabase.Password)"
        try {
            Invoke-CheckedCommand `
                -FilePath 'dotnet' `
                -Arguments @(
                    'test', $solution,
                    '--configuration', 'Release',
                    '--no-build',
                    '--no-restore',
                    '--nologo',
                    '--results-directory', $testResultsDirectory,
                    '--logger', "trx;LogFilePrefix=phase7-$run"
                ) `
                -WorkingDirectory $repoRoot `
                -LogPath (Join-Path $ArtifactsDirectory "dotnet-test-run-$run.log") `
                -Description "Run all backend tests ($run/$Repeat)"
        }
        finally {
            if ($null -eq $previousAdminConnection) {
                Remove-Item Env:CARESITTER_TEST_ADMIN_CONNECTION -ErrorAction SilentlyContinue
            }
            else {
                $env:CARESITTER_TEST_ADMIN_CONNECTION = $previousAdminConnection
            }
        }

        $testCounters = Get-TestCounters -ResultsDirectory $testResultsDirectory
        if ($testCounters.Failed -ne 0 -or $testCounters.NotExecuted -ne 0 -or
            $testCounters.Total -ne $testCounters.Passed) {
            throw "Backend tests were not fully green: $($testCounters | ConvertTo-Json -Compress)"
        }

        if (-not $SkipFrontend) {
            foreach ($appName in @('customer-app', 'caregiver-app')) {
                $appDirectory = Join-Path (Join-Path $repoRoot 'frontend') $appName
                Invoke-CheckedCommand `
                    -FilePath $flutterCommand `
                    -Arguments @('pub', 'get') `
                    -WorkingDirectory $appDirectory `
                    -LogPath (Join-Path $ArtifactsDirectory "$appName-pub-get-run-$run.log") `
                    -Description "Resolve $appName dependencies ($run/$Repeat)"
                Invoke-CheckedCommand `
                    -FilePath $flutterCommand `
                    -Arguments @('analyze', '--no-pub') `
                    -WorkingDirectory $appDirectory `
                    -LogPath (Join-Path $ArtifactsDirectory "$appName-analyze-run-$run.log") `
                    -Description "Analyze $appName ($run/$Repeat)"
                Invoke-CheckedCommand `
                    -FilePath $flutterCommand `
                    -Arguments @('test', '--no-pub') `
                    -WorkingDirectory $appDirectory `
                    -LogPath (Join-Path $ArtifactsDirectory "$appName-test-run-$run.log") `
                    -Description "Test $appName ($run/$Repeat)"
            }

            $adminDirectory = Join-Path (Join-Path $repoRoot 'frontend') 'admin-web'
            Invoke-CheckedCommand `
                -FilePath $npmCommand `
                -Arguments @('ci') `
                -WorkingDirectory $adminDirectory `
                -LogPath (Join-Path $ArtifactsDirectory "admin-npm-ci-run-$run.log") `
                -Description "Install admin web dependencies ($run/$Repeat)"
            Invoke-CheckedCommand `
                -FilePath $npmCommand `
                -Arguments @('run', 'build') `
                -WorkingDirectory $adminDirectory `
                -LogPath (Join-Path $ArtifactsDirectory "admin-build-run-$run.log") `
                -Description "Build admin web ($run/$Repeat)"
        }

        $runSummaries.Add([pscustomobject]@{
            Run = $run
            CompletedAt = (Get-Date).ToString('o')
            CleanDatabaseSignature = $cleanSignature
            LegacySignatureBefore = $legacyResult.Before
            LegacySignatureAfter = $legacyResult.After
            BackendTests = $testCounters
            FrontendChecked = -not $SkipFrontend
            Smoke = 'passed'
            ComposeHealth = 'passed'
        })

        Write-Host "PASS  Phase 7 acceptance run $run/$Repeat"
    }

    $summary = [pscustomobject]@{
        Status = 'passed'
        RunId = $runId
        StartedFromCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
        WorkingTreeDirty = (@(& git -C $repoRoot status --porcelain)).Count -gt 0
        Repeat = $Repeat
        CompletedAt = (Get-Date).ToString('o')
        Runs = $runSummaries
    }
    $summaryPath = Join-Path $ArtifactsDirectory 'summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "`nPhase 7 acceptance passed $Repeat consecutive run(s)."
    Write-Host "Evidence: $summaryPath"
}
finally {
    Stop-Phase7Api -Process $apiProcess
    foreach ($containerName in $temporaryContainers) {
        & docker rm --force $containerName *> $null
    }
    foreach ($directory in $temporaryDirectories) {
        if (Test-Path -LiteralPath $directory) {
            Remove-Item -LiteralPath $directory -Recurse -Force
        }
    }
}
