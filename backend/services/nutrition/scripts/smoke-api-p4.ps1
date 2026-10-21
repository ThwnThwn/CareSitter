[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5033',
    [string]$CustomerEmail = 'nguoithan@example.com',
    [string]$TestPassword = $env:CARESITTER_SMOKE_TEST_PASSWORD,
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$serviceRoot = Split-Path $PSScriptRoot -Parent
$backendRoot = [IO.Path]::GetFullPath((Join-Path $serviceRoot '../..'))
$apiProject = Join-Path $backendRoot 'caresitter-be/ApiHost/CareSitter.ApiHost.csproj'
$nutritionProject = Join-Path $serviceRoot 'src/CareSitter.Nutrition/CareSitter.Nutrition.csproj'
$apiAssembly = Join-Path (Split-Path $apiProject -Parent) 'bin/Debug/net8.0/CareSitter.ApiHost.dll'
$nutritionAssembly = Join-Path (Split-Path $nutritionProject -Parent) 'bin/Debug/net8.0/CareSitter.Nutrition.dll'
$apiEnvironmentFile = Join-Path $backendRoot '.env'
$databaseConfigPath = Join-Path $serviceRoot 'nutrition-db.local.json'
$catalogFixturePath = Join-Path $serviceRoot 'catalog/fixtures/p4-api-smoke.bundle.json'
$psql = Join-Path $PostgresBin 'psql.exe'
$runId = [Guid]::NewGuid().ToString('N')
$databaseName = "caresitter_nutrition_smoke_$runId"
$artifactRoot = Join-Path $backendRoot "artifacts/nutrition-p4-smoke/$runId"
$resultPath = Join-Path $artifactRoot 'result.json'
$base = $BaseUrl.TrimEnd('/')

if ([string]::IsNullOrWhiteSpace($TestPassword)) {
    throw 'Set CARESITTER_SMOKE_TEST_PASSWORD or pass -TestPassword. The value is never written to the smoke artifact.'
}
foreach ($path in @($apiProject, $nutritionProject, $apiEnvironmentFile, $catalogFixturePath, $psql)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required smoke dependency is missing: $path" }
}
if ($databaseName -notmatch '^caresitter_nutrition_smoke_[a-f0-9]{32}$') {
    throw 'Generated smoke database name is outside the permitted pattern.'
}
foreach ($port in @(5033, 5035, 5036)) {
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
        throw "Port $port is already in use. Stop the existing local stack before running the isolated P4 smoke."
    }
}

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

$apiProcess = $null
$nutritionProcess = $null
$databaseCreated = $false
$catalogPublished = $false
$beneficiaryId = $null
$sessionHeaders = $null
$refreshToken = $null
$cleanup = [ordered]@{
    beneficiaryDelete = 'not_started'
    sessionRevoke = 'not_started'
    catalogRetire = 'not_started'
    databaseDrop = 'not_started'
}
$report = [ordered]@{
    timestamp = [DateTimeOffset]::Now.ToString('O')
    runId = $runId
    transport = 'REST ApiHost -> gRPC Nutrition -> PostgreSQL'
    fixture = 'synthetic_p4_only'
    checks = [ordered]@{}
    cleanup = $cleanup
}
$environmentNames = @(
    'ASPNETCORE_ENVIRONMENT', 'ASPNETCORE_URLS', 'CARESITTER_ENV_FILE',
    'Jwt__SecretKey', 'Jwt__Issuer', 'Jwt__Audience',
    'Gateway__ServiceKey', 'People__ServiceKey', 'People__BaseUrl', 'ConnectionStrings__Nutrition',
    'Nutrition__Enabled', 'Nutrition__AssessmentsEnabled', 'Nutrition__RecommendationsEnabled',
    'HealthParser__Enabled', 'Kestrel__Endpoints__Http__Url', 'Kestrel__Endpoints__Http__Protocols',
    'Kestrel__Endpoints__Grpc__Url', 'Kestrel__Endpoints__Grpc__Protocols',
    'NutritionIntegration__ServiceKey', 'NutritionGateway__Enabled', 'NutritionGateway__GrpcUrl',
    'NutritionGateway__ServiceKey'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Read-EnvironmentValue([string]$name) {
    $line = Get-Content -LiteralPath $apiEnvironmentFile |
        Where-Object { $_ -match "^$([regex]::Escape($name))=" } |
        Select-Object -Last 1
    if ($null -eq $line) { throw "Missing local API configuration key: $name" }
    $value = ($line -split '=', 2)[1].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Local API configuration key is empty: $name" }
    return $value
}

function Invoke-AdminPsql {
    param(
        [Parameter(Mandatory)][string]$Database,
        [string]$Sql,
        [string]$File,
        [switch]$TuplesOnly
    )
    $arguments = @('-X', '-q', '-h', '127.0.0.1', '-p', "$($script:databaseConfig.Port)",
        '-U', 'postgres', '-d', $Database, '-v', 'ON_ERROR_STOP=1')
    if ($TuplesOnly) { $arguments += @('-A', '-t') }
    if ($File) { $arguments += @('-f', $File) }
    $previousPassword = $env:PGPASSWORD
    try {
        $env:PGPASSWORD = $script:databaseConfig.AdminPassword
        if ($Sql) { $output = $Sql | & $script:psql @arguments 2>&1 }
        else { $output = & $script:psql @arguments 2>&1 }
        if ($LASTEXITCODE -ne 0) { throw "PostgreSQL smoke command failed for database $Database." }
        return @($output)
    }
    finally {
        if ($null -eq $previousPassword) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
        else { $env:PGPASSWORD = $previousPassword }
    }
}

function Invoke-SmokeRequest {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body,
        [hashtable]$Headers
    )
    $parameters = @{
        Uri = "$base$Path"
        Method = $Method
        UseBasicParsing = $true
        SkipHttpErrorCheck = $true
        TimeoutSec = 15
    }
    if ($null -ne $Headers) { $parameters.Headers = $Headers }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body | ConvertTo-Json -Depth 30 -Compress
    }
    $response = Invoke-WebRequest @parameters
    $parsed = $null
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try { $parsed = $response.Content | ConvertFrom-Json -Depth 40 }
        catch { $parsed = $response.Content }
    }
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed }
}

function Assert-Equal($actual, $expected, [string]$name) {
    if ($actual -ne $expected) { throw "$name was '$actual'; expected '$expected'." }
}

function Wait-Assessment([Guid]$id) {
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $response = Invoke-SmokeRequest -Method Get -Path "/api/v1/beneficiaries/$beneficiaryId/nutrition-assessments/$id" -Headers $sessionHeaders
        Assert-Equal $response.Status 200 'Assessment poll HTTP status'
        if ($response.Body.status -notin @('queued', 'processing')) { return $response }
        Start-Sleep -Milliseconds 250
    }
    throw "Assessment $id did not reach a terminal state."
}

function Wait-Ready([string]$uri, [Diagnostics.Process]$process, [string]$name) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if ($process.HasExited) { throw "$name exited before becoming ready. Inspect the isolated smoke logs." }
        try {
            if ((Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 2).StatusCode -eq 200) { return }
        }
        catch { }
        Start-Sleep -Milliseconds 500
    }
    throw "$name did not become ready. Inspect the isolated smoke logs."
}

try {
    & dotnet build $nutritionProject --no-restore --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw 'Nutrition build failed before smoke startup.' }
    & dotnet build $apiProject --no-restore --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw 'ApiHost build failed before smoke startup.' }
    foreach ($assembly in @($nutritionAssembly, $apiAssembly)) {
        if (-not (Test-Path -LiteralPath $assembly)) { throw "Smoke assembly was not produced: $assembly" }
    }

    & (Join-Path $PSScriptRoot 'start-local-db.ps1') -PostgresBin $PostgresBin | Out-Null
    $databaseConfig = Get-Content -LiteralPath $databaseConfigPath -Raw | ConvertFrom-Json
    Invoke-AdminPsql -Database 'postgres' -Sql "CREATE DATABASE `"$databaseName`";" | Out-Null
    $databaseCreated = $true

    foreach ($migration in @(
        'init-db/nutrition-service/01-nutrition-workflow.sql',
        'init-db/nutrition-service/03-catalog-governance.sql',
        'init-db/nutrition-service/04-catalog-nutrient-constraints.sql',
        'init-db/nutrition-service/05-recipe-source-citations.sql',
        'init-db/nutrition-service/06-catalog-release-evidence.sql',
        'init-db/nutrition-service/07-catalog-knowledge-review-gate.sql',
        'init-db/nutrition-service/08-local-demo-catalog.sql')) {
        Invoke-AdminPsql -Database $databaseName -File (Join-Path $backendRoot $migration) | Out-Null
    }
    Invoke-AdminPsql -Database $databaseName -Sql @"
GRANT CONNECT ON DATABASE "$databaseName" TO nutrition_app;
GRANT USAGE ON SCHEMA nutrition TO nutrition_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON nutrition.assessments,nutrition.assessment_jobs,
 nutrition.recommendations,nutrition.meal_plans,nutrition.preferences TO nutrition_app;
GRANT SELECT ON nutrition.recipe_versions,nutrition.rule_versions,nutrition.concepts,
 nutrition.recipe_source_citations,nutrition.local_demo_catalog TO nutrition_app;
GRANT SELECT,UPDATE(id) ON nutrition.catalog_state TO nutrition_app;
"@ | Out-Null

    $packageId = [Guid]::NewGuid()
    # Expand the isolated synthetic fixture to the P2A release shape; never write it to the real catalog.
    $fixture = Get-Content -LiteralPath $catalogFixturePath -Raw | ConvertFrom-Json
    $recipes = @($fixture.recipes)
    foreach ($meal in @('breakfast', 'lunch', 'dinner')) {
        $original = @($recipes | Where-Object { $_.payload.mealType -eq $meal })
        while (@($recipes | Where-Object { $_.payload.mealType -eq $meal }).Count -lt 4) {
            $copy = $original[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            $copy.recipeId = [Guid]::NewGuid().ToString()
            $copy.payload.versionId = [Guid]::NewGuid().ToString()
            $copy.payload.name += ' (smoke variant)'
            $recipes += $copy
        }
    }
    $fixture.recipes = $recipes
    foreach ($recipe in $fixture.recipes) {
        foreach ($nutrient in @('carbohydrate_g', 'fat_g', 'fiber_g')) {
            $recipe.payload.nutrients | Add-Member -NotePropertyName $nutrient -NotePropertyValue 1 -Force
        }
    }
    $bundleJson = $fixture | ConvertTo-Json -Depth 100 -Compress
    $bundleSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($bundleJson))).ToLowerInvariant()
    $evidence = [ordered]@{
        schemaVersion = 1
        packageKey = $fixture.packageKey
        bundleFileSha256 = $bundleSha
        contentStatus = 'review_ready'
        releaseProfile = 'adult_baseline_v1'
        requiredNutrients = @('energy_kcal', 'protein_g', 'carbohydrate_g', 'fat_g', 'fiber_g', 'sodium_mg')
        recipes = @($fixture.recipes | ForEach-Object {
            $nutrients = $_.payload.nutrients
            [ordered]@{
                recipeVersionId = $_.payload.versionId
                ingredients = @($_.payload.ingredients)
                nutrients = @($nutrients.PSObject.Properties | ForEach-Object { @{ key = $_.Name; value = $_.Value } })
                unresolvedItems = @()
            }
        })
        rules = @()
        clinicalReview = @{
            reviewerName = 'Synthetic smoke reviewer'
            reviewerId = 'synthetic-smoke-reviewer'
            credentials = 'Automated test fixture only'
            reviewedAt = [DateTimeOffset]::UtcNow.ToString('O')
            decision = 'approved'
        }
        knowledgeReview = @{
            schemaVersion = 1
            candidateGraphSha256 = ('b' * 64)
            decisionLedgerSha256 = ('c' * 64)
            reviewedGraphSha256 = ('d' * 64)
            candidateCount = @($fixture.recipes).Count
            approvedCount = @($fixture.recipes).Count
            pendingCount = 0
            rejectedCount = 0
            sources = @(@{ sourceRevisionId = 'synthetic-p4-smoke@1'; rightsStatus = 'permitted' })
            clinicalReviewerIds = @('synthetic-smoke-reviewer')
            decision = 'approved'
        }
    }
    $payload = $bundleJson.Replace("'", "''")
    $evidenceJson = ($evidence | ConvertTo-Json -Depth 100 -Compress).Replace("'", "''")
    $importOutput = Invoke-AdminPsql -Database $databaseName -TuplesOnly -Sql @"
SET SESSION AUTHORIZATION nutrition_catalog_importer;
SELECT nutrition.import_catalog_bundle('$packageId','p4-api-smoke','$payload'::jsonb);
"@
    $importResult = ($importOutput | Where-Object { $_.ToString().TrimStart().StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json
    $digest = $importResult.digest
    if ($digest -notmatch '^[a-f0-9]{64}$') { throw 'Catalog import did not return a valid digest.' }
    Invoke-AdminPsql -Database $databaseName -TuplesOnly -Sql @"
SET SESSION AUTHORIZATION nutrition_catalog_reviewer;
SELECT nutrition.record_catalog_release_evidence('$packageId','$digest','$payload'::jsonb,'$evidenceJson'::jsonb);
SELECT nutrition.review_catalog_bundle('$packageId','$digest');
"@ | Out-Null
    Invoke-AdminPsql -Database $databaseName -TuplesOnly -Sql @"
SET SESSION AUTHORIZATION nutrition_catalog_publisher;
SELECT nutrition.publish_catalog_bundle('$packageId','$digest');
"@ | Out-Null
    $catalogPublished = $true

    $jwtSecret = Read-EnvironmentValue 'Jwt__SecretKey'
    $jwtIssuer = Read-EnvironmentValue 'Jwt__Issuer'
    $jwtAudience = Read-EnvironmentValue 'Jwt__Audience'
    $gatewayKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $peopleKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $runtimeConnection = "Host=127.0.0.1;Port=$($databaseConfig.Port);Database=$databaseName;Username=nutrition_app;Password=$($databaseConfig.AppPassword)"

    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:Jwt__SecretKey = $jwtSecret
    $env:Jwt__Issuer = $jwtIssuer
    $env:Jwt__Audience = $jwtAudience
    $env:Gateway__ServiceKey = $gatewayKey
    $env:People__ServiceKey = $peopleKey
    $env:People__BaseUrl = 'http://localhost:5033/'
    $env:ConnectionStrings__Nutrition = $runtimeConnection
    $env:Nutrition__Enabled = 'true'
    $env:Nutrition__AssessmentsEnabled = 'true'
    $env:Nutrition__RecommendationsEnabled = 'true'
    $env:HealthParser__Enabled = 'false'
    $env:Kestrel__Endpoints__Http__Url = 'http://localhost:5035'
    $env:Kestrel__Endpoints__Http__Protocols = 'Http1'
    $env:Kestrel__Endpoints__Grpc__Url = 'http://localhost:5036'
    $env:Kestrel__Endpoints__Grpc__Protocols = 'Http2'
    $nutritionProcess = Start-Process dotnet -ArgumentList @($nutritionAssembly) `
        -WorkingDirectory $serviceRoot -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $artifactRoot 'nutrition.stdout.log') `
        -RedirectStandardError (Join-Path $artifactRoot 'nutrition.stderr.log') -PassThru

    foreach ($name in @('Gateway__ServiceKey', 'People__ServiceKey', 'People__BaseUrl', 'ConnectionStrings__Nutrition',
        'Nutrition__Enabled', 'Nutrition__AssessmentsEnabled', 'Nutrition__RecommendationsEnabled', 'HealthParser__Enabled',
        'Kestrel__Endpoints__Http__Url', 'Kestrel__Endpoints__Http__Protocols',
        'Kestrel__Endpoints__Grpc__Url', 'Kestrel__Endpoints__Grpc__Protocols')) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    $env:CARESITTER_ENV_FILE = $apiEnvironmentFile
    $env:ASPNETCORE_URLS = 'http://localhost:5033'
    $env:NutritionIntegration__ServiceKey = $peopleKey
    $env:NutritionGateway__Enabled = 'true'
    $env:NutritionGateway__GrpcUrl = 'http://localhost:5036/'
    $env:NutritionGateway__ServiceKey = $gatewayKey
    $apiProcess = Start-Process dotnet -ArgumentList @($apiAssembly) `
        -WorkingDirectory (Split-Path $apiProject -Parent) -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $artifactRoot 'api.stdout.log') `
        -RedirectStandardError (Join-Path $artifactRoot 'api.stderr.log') -PassThru

    Wait-Ready 'http://localhost:5035/health/ready' $nutritionProcess 'Nutrition service'
    Wait-Ready "$base/health/ready" $apiProcess 'ApiHost'

    $anonymous = Invoke-SmokeRequest -Method Get -Path '/api/v1/nutrition/capabilities'
    Assert-Equal $anonymous.Status 401 'Anonymous capabilities HTTP status'
    $login = Invoke-SmokeRequest -Method Post -Path '/api/v1/auth/login/password' -Body @{
        email = $CustomerEmail
        password = $TestPassword
        requiredRole = 'CUSTOMER'
    }
    Assert-Equal $login.Status 200 'Customer login HTTP status'
    if ([string]::IsNullOrWhiteSpace($login.Body.accessToken) -or $login.Body.roles -notcontains 'CUSTOMER') {
        throw 'Customer login response is missing the expected token or role.'
    }
    $sessionHeaders = @{ Authorization = "Bearer $($login.Body.accessToken)" }
    $refreshToken = $login.Body.refreshToken

    $capabilities = Invoke-SmokeRequest -Method Get -Path '/api/v1/nutrition/capabilities' -Headers $sessionHeaders
    Assert-Equal $capabilities.Status 200 'Authenticated capabilities HTTP status'
    foreach ($flag in @('enabled', 'assessmentsEnabled', 'recommendationsEnabled')) {
        if ($capabilities.Body.$flag -ne $true) { throw "Capability $flag is not enabled." }
    }
    if ($capabilities.Body.freeTextParserReady -ne $false) { throw 'Provider parser must remain disabled during P4 smoke.' }

    $create = Invoke-SmokeRequest -Method Post -Path '/api/v1/beneficiaries' -Headers $sessionHeaders -Body @{
        fullName = "Nutrition P4 Smoke $($runId.Substring(0, 8))"
        dateOfBirth = '1960-06-15'
        gender = 'FEMALE'
        relationshipToCustomer = 'Fixture tổng hợp'
        defaultAddressId = 'a0000000-0000-0000-0000-000000000071'
        allergies = @()
        chronicConditions = @()
        emergencyContacts = @()
        medications = @()
    }
    Assert-Equal $create.Status 201 'Beneficiary create HTTP status'
    $beneficiaryId = [Guid]$create.Body.id

    $health = Invoke-SmokeRequest -Method Get -Path "/api/v1/beneficiaries/$beneficiaryId/health-profile" -Headers $sessionHeaders
    Assert-Equal $health.Status 200 'Initial health profile HTTP status'
    $initialRevision = [long]$health.Body.revision

    $missingCreate = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/nutrition-assessments" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $initialRevision
        idempotencyKey = [Guid]::NewGuid()
    }
    Assert-Equal $missingCreate.Status 202 'Missing-information assessment create HTTP status'
    $missing = Wait-Assessment ([Guid]$missingCreate.Body.id)
    Assert-Equal $missing.Body.status 'needs_information' 'Missing-information assessment state'
    $questions = @($missing.Body.data.decision.questions)
    if ($questions.Count -lt 1 -or $questions.Count -gt 3) { throw 'Clarification question count must be between one and three.' }
    if ($questions[0].id -ne 'food-allergy-status.v1') { throw 'The first deterministic clarification question is unexpected.' }

    $patch = Invoke-SmokeRequest -Method Patch -Path "/api/v1/beneficiaries/$beneficiaryId/health-profile" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $initialRevision
        changes = @{
            foodAllergyStatus = 'reported_none'
            nutritionProfile = @{
                conditionsStatus = 'reported_none'
                medicationsStatus = 'reported_none'
                feedingRoute = 'oral'
                swallowingStatus = 'normal'
                fluidRestriction = 'none'
                electrolyteRestriction = 'none'
            }
        }
    }
    Assert-Equal $patch.Status 200 'Health profile patch HTTP status'
    $healthRevision = [long]$patch.Body.revision

    $assessmentCreate = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/nutrition-assessments" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $healthRevision
        idempotencyKey = [Guid]::NewGuid()
    }
    Assert-Equal $assessmentCreate.Status 202 'Complete assessment create HTTP status'
    $assessment = Wait-Assessment ([Guid]$assessmentCreate.Body.id)
    Assert-Equal $assessment.Body.status 'awaiting_confirmation' 'Analyzed assessment state'

    $confirm = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/nutrition-assessments/$($assessment.Body.id)/confirm" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $healthRevision
        idempotencyKey = [Guid]::NewGuid()
    }
    Assert-Equal $confirm.Status 200 'Assessment confirmation HTTP status'
    Assert-Equal $confirm.Body.status 'confirmed' 'Confirmed assessment resource state'
    Assert-Equal $confirm.Body.data.decision.state 'eligible' 'Confirmed assessment decision state'

    $recommend = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/meal-recommendations" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $healthRevision
        idempotencyKey = [Guid]::NewGuid()
        assessmentId = [Guid]$assessment.Body.id
        plannedDate = [DateOnly]::FromDateTime([DateTime]::Now).ToString('yyyy-MM-dd')
    }
    Assert-Equal $recommend.Status 200 'Recommendation HTTP status'
    Assert-Equal $recommend.Body.status 'suggested' 'Recommendation state'
    $meals = @($recommend.Body.data.meals)
    Assert-Equal $meals.Count 3 'Recommended meal count'
    foreach ($meal in $meals) {
        $details = @($meal.sourceDetails)
        Assert-Equal $details.Count 1 "Source detail count for $($meal.mealType)"
        Assert-Equal $details[0].title 'Nguồn tổng hợp kiểm thử P4' 'Source title'
        Assert-Equal $details[0].organization 'CareSitter QA' 'Source organization'
        if ($details[0].PSObject.Properties.Name -contains 'fileSha256') { throw 'Runtime source metadata exposed fileSha256.' }
    }

    $options = Invoke-SmokeRequest -Method Get -Path "/api/v1/beneficiaries/$beneficiaryId/meal-recommendations/$($recommend.Body.id)/replacement-options?mealType=lunch" -Headers $sessionHeaders
    Assert-Equal $options.Status 200 'Replacement options HTTP status'
    $replacementOptions = @($options.Body)
    if ($replacementOptions.Count -lt 1) { throw 'Replacement options must contain at least one eligible recipe.' }
    Assert-Equal @($replacementOptions[0].sourceDetails).Count 1 'Replacement source detail count'

    $replace = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/meal-recommendations/$($recommend.Body.id)/replacements" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $healthRevision
        idempotencyKey = [Guid]::NewGuid()
        mealType = 'lunch'
        recipeVersionId = [Guid]$replacementOptions[0].versionId
    }
    Assert-Equal $replace.Status 200 'Meal replacement HTTP status'
    Assert-Equal $replace.Body.status 'suggested' 'Meal replacement state'

    $save = Invoke-SmokeRequest -Method Post -Path "/api/v1/beneficiaries/$beneficiaryId/meal-plans" -Headers $sessionHeaders -Body @{
        expectedHealthRevision = $healthRevision
        idempotencyKey = [Guid]::NewGuid()
        recommendationId = [Guid]$replace.Body.id
    }
    Assert-Equal $save.Status 200 'Meal plan save HTTP status'
    Assert-Equal $save.Body.status 'saved' 'Meal plan state'
    Assert-Equal @($save.Body.data.meals).Count 3 'Saved meal count'
    Assert-Equal @($save.Body.data.meals[0].sourceDetails).Count 1 'Saved source detail count'

    $report.checks = [ordered]@{
        anonymousCapabilities = $anonymous.Status
        authenticatedCapabilities = $capabilities.Status
        freeTextParserReady = $capabilities.Body.freeTextParserReady
        missingInformation = [ordered]@{
            status = $missing.Body.status
            questionCount = $questions.Count
            questionIds = @($questions | ForEach-Object { $_.id })
        }
        completeFlow = [ordered]@{
            analyzed = $assessment.Body.status
            confirmed = $confirm.Body.status
            recommended = $recommend.Body.status
            mealCount = $meals.Count
            replacementOptions = $replacementOptions.Count
            replaced = $replace.Body.status
            saved = $save.Body.status
        }
        sourceMetadata = [ordered]@{
            id = $meals[0].sourceDetails[0].id
            title = $meals[0].sourceDetails[0].title
            organization = $meals[0].sourceDetails[0].organization
            year = $meals[0].sourceDetails[0].year
            verifiedOn = $meals[0].sourceDetails[0].verifiedOn
            fileSha256Exposed = $false
        }
    }

    $delete = Invoke-SmokeRequest -Method Delete -Path "/api/v1/beneficiaries/$beneficiaryId" -Headers $sessionHeaders
    Assert-Equal $delete.Status 204 'Beneficiary cleanup HTTP status'
    $cleanup.beneficiaryDelete = '204'
    $beneficiaryId = $null

    $logout = Invoke-SmokeRequest -Method Post -Path '/api/v1/auth/logout' -Headers $sessionHeaders -Body @{ refreshToken = $refreshToken }
    Assert-Equal $logout.Status 204 'Session revoke HTTP status'
    $cleanup.sessionRevoke = '204'
    $sessionHeaders = $null
    $refreshToken = $null

    Write-Host 'PASS  P4 ApiHost smoke completed: questions, generate, replace, save and source metadata.'
}
finally {
    if ($null -ne $beneficiaryId -and $null -ne $sessionHeaders) {
        try {
            $delete = Invoke-SmokeRequest -Method Delete -Path "/api/v1/beneficiaries/$beneficiaryId" -Headers $sessionHeaders
            $cleanup.beneficiaryDelete = "$($delete.Status)"
        }
        catch { $cleanup.beneficiaryDelete = 'failed' }
    }
    if ($null -ne $sessionHeaders) {
        try {
            $logout = Invoke-SmokeRequest -Method Post -Path '/api/v1/auth/logout' -Headers $sessionHeaders -Body @{ refreshToken = $refreshToken }
            $cleanup.sessionRevoke = "$($logout.Status)"
        }
        catch { $cleanup.sessionRevoke = 'failed' }
    }
    if ($catalogPublished -and $databaseCreated) {
        try {
            Invoke-AdminPsql -Database $databaseName -TuplesOnly -Sql @"
SET SESSION AUTHORIZATION nutrition_catalog_publisher;
SELECT nutrition.retire_catalog_bundle('$packageId','P4 API smoke completed');
"@ | Out-Null
            $cleanup.catalogRetire = 'retired'
        }
        catch { $cleanup.catalogRetire = 'failed' }
    }
    foreach ($process in @($apiProcess, $nutritionProcess)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
    }
    if ($databaseCreated) {
        try {
            Invoke-AdminPsql -Database 'postgres' -Sql @"
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$databaseName' AND pid<>pg_backend_pid();
DROP DATABASE "$databaseName";
"@ | Out-Null
            $cleanup.databaseDrop = 'dropped'
        }
        catch { $cleanup.databaseDrop = 'failed' }
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding utf8
    Write-Host "Redacted smoke artifact: $resultPath"
}
