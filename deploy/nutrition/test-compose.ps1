param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'assert-networks.ps1')
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
KAFKA_INTERNAL_SERVICE_KEY=$secret
KAFKA_FLOW_NUTRITION_ENABLED=true
"@)
try {
    & docker compose --project-directory (Join-Path $repository 'deploy') --env-file $envFile -f (Join-Path $repository 'deploy/compose.yml') -f (Join-Path $repository 'deploy/nutrition/compose.yml') --profile nutrition-migrate --profile nutrition-ops --profile nutrition-smoke --profile nutrition-catalog config --format json 1> $configFile 2> (Join-Path $state 'compose-errors.log')
    if ($LASTEXITCODE -ne 0) { throw "Compose validation failed; inspect $state." }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    Assert-NutritionNetworks $config
    if ($config.services.nutrition.environment.MealGrounding__AllowNonMedicalReference -eq 'true') { throw 'Base deployment must not allow non-medical reference artifacts.' }
    if ($config.services.nutrition.environment.NutritionCatalog__LocalDemoEnabled -ne 'false') { throw 'Base deployment must disable the local demo catalog.' }
    if ($config.services.'nutrition-catalog-check'.environment.PGUSER -ne 'nutrition_app') { throw 'Published catalog check must use runtime privileges.' }
    $catalogCheck = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'check-published-catalog.sql') -Raw
    if ($catalogCheck -notmatch "current_catalog_review_policy\(\)='source_and_clinical'" -or
        $catalogCheck -notmatch 'published_catalog_review_policies\(\)') { throw 'Production catalog check must reject the non_medical_reference policy.' }
    if ($config.services.'nutrition-catalog-check'.secrets.Where({$_.source -eq 'nutrition_db_admin'})) { throw 'Published catalog check must not receive admin credentials.' }
    foreach ($job in @('nutrition-catalog', 'nutrition-catalog-check')) {
        $attached = @($config.services.$job.networks.PSObject.Properties.Name)
        if ($attached.Count -ne 1 -or $attached[0] -ne 'nutrition-data') { throw 'Catalog jobs must remain on the private Nutrition network.' }
    }
    if (!$config.services.'nutrition-catalog'.volumes.Where({$_.target -eq '/catalog' -and $_.read_only})) { throw 'Release artifacts must be mounted read-only.' }
    if (!$config.services.'nutrition-catalog'.secrets.Where({$_.source -eq 'nutrition_catalog_connection'})) { throw 'Catalog operations need a dedicated role connection secret.' }
    if ($config.services.nutrition.secrets.Where({$_.source -eq 'nutrition_catalog_connection'})) { throw 'Runtime must not receive catalog mutation credentials.' }
    # Exercise the AI-enabled base configuration without changing approval flags.
    $config.services.nutrition.environment.HealthParser__Enabled = 'true'
    Assert-NutritionNetworks $config
    $config.services.nutrition.environment.HealthParser__Enabled = 'false'
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
    $opsCopies = @('common.sh','migrate.sh','backup.sh','restore-check.sh','smoke.sh','check-published-catalog.sh','check-published-catalog.sql','catalog-tool-entrypoint.sh')
    foreach ($file in $opsCopies) { if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Ops Docker build references missing $file." } }
    & docker compose --project-directory (Join-Path $repository 'deploy') --env-file $envFile -f (Join-Path $repository 'deploy/compose.yml') -f (Join-Path $repository 'deploy/nutrition/compose.yml') -f (Join-Path $repository 'deploy/compose.kafka.yml') config --format json 1> $configFile 2> (Join-Path $state 'compose-kafka-errors.log')
    if ($LASTEXITCODE -ne 0) { throw "Kafka overlay validation failed; inspect $state." }
    $withKafka = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    Assert-NutritionNetworks $withKafka
    $nutritionNetworks = @($withKafka.services.nutrition.networks.PSObject.Properties.Name)
    $kafkaNetworks = @($withKafka.services.kafka.networks.PSObject.Properties.Name)
    if ($nutritionNetworks -notcontains 'nutrition-messaging' -or
        $nutritionNetworks -contains 'data' -or
        $kafkaNetworks -notcontains 'nutrition-messaging' -or
        [string]$withKafka.services.nutrition.environment.BeneficiaryEvents__Enabled -ne 'true') {
        throw 'Nutrition Kafka network or consumer flag is misconfigured.'
    }
    Write-Output 'PASS: Compose merge, AI egress isolation, private DB/gRPC ports, TLS endpoints, readiness ordering, disabled flags and secret isolation.'
    Write-Output 'This offline check does not build images or start containers.'
}
finally {
    # These files contain only generated fixture credentials and are not needed after validation.
    Remove-Item -LiteralPath $envFile -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $configFile -ErrorAction SilentlyContinue
}
