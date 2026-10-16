param()
$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$state = Join-Path $repository ('backend/artifacts/nutrition-staging-20261013/compose-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $state | Out-Null
$envFile = Join-Path $state 'fixture.env'
$configFile = Join-Path $state 'config.json'
$secret = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($envFile, @"
APP_ENVIRONMENT=Staging
APP_DOMAIN=staging.caresitter.test
POSTGRES_DB=caresitter
POSTGRES_USER=fixture
POSTGRES_PASSWORD=$secret
REDIS_PASSWORD=$secret
Jwt__SecretKey=$secret
Jwt__Issuer=fixture
Jwt__Audience=fixture
Public__ApiBaseUrl=https://staging.caresitter.test
CARESITTER_ENV_FILE=$($envFile.Replace('\','/'))
"@)
try {
    & docker compose --project-directory (Join-Path $repository 'deploy') --env-file $envFile -f (Join-Path $repository 'deploy/compose.yml') -f (Join-Path $repository 'deploy/nutrition/compose.yml') --profile nutrition-migrate --profile nutrition-ops --profile nutrition-smoke config --format json 1> $configFile 2> (Join-Path $state 'compose-errors.log')
    if ($LASTEXITCODE -ne 0) { throw "Compose validation failed; inspect $state." }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    foreach ($name in @('db','redis','api','nutrition-db','nutrition')) {
        if ($config.services.$name.ports) { throw "Service $name unexpectedly publishes a port." }
    }
    if (!$config.networks.'nutrition-data'.internal) { throw 'Nutrition network must remain private.' }
    if ($config.services.nutrition.networks.edge) { throw 'Nutrition must not join the public proxy network.' }
    if ($config.services.api.depends_on.nutrition.condition -ne 'service_healthy') { throw 'Gateway starts before Nutrition readiness.' }
    if ($config.services.nutrition.environment.People__BaseUrl -ne 'https://api:8443/' -or $config.services.api.environment.NutritionGateway__GrpcUrl -ne 'https://nutrition:8443/') { throw 'Internal endpoints must use HTTPS.' }
    foreach ($flag in @('Nutrition__Enabled','Nutrition__AssessmentsEnabled','Nutrition__RecommendationsEnabled','HealthParser__Enabled')) {
        if ($config.services.nutrition.environment.$flag -ne 'false') { throw 'The infrastructure package must default to disabled business features.' }
    }
    if (!$config.services.'nutrition-db'.volumes.Where({$_.source -eq 'nutrition_pgdata'})) { throw 'Nutrition DB does not use its dedicated volume.' }
    foreach ($name in @('api','nutrition','nutrition-backup')) {
        if ($config.services.$name.secrets.Where({$_.source -eq 'backup_identity'})) { throw 'Recovery identity is mounted outside the restore job.' }
    }
    if ($config.services.'nutrition-backup'.environment.PGPASSWORD -or $config.services.nutrition.environment.ConnectionStrings__Nutrition) { throw 'Nutrition database credentials must come from secret files.' }
    $opsCopies = @('common.sh','migrate.sh','backup.sh','restore-check.sh','smoke.sh')
    foreach ($file in $opsCopies) { if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Ops Docker build references missing $file." } }
    Write-Output 'PASS: Compose merge, private DB/gRPC ports, TLS endpoints, readiness ordering, disabled flags and secret isolation.'
    Write-Output 'This offline check does not build images or start containers.'
}
finally {
    # These files contain only generated fixture credentials and are not needed after validation.
    Remove-Item -LiteralPath $envFile -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $configFile -ErrorAction SilentlyContinue
}
