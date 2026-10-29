[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$state = Join-Path $repository ('backend/artifacts/nutrition-demo-compose-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $state | Out-Null
$mainEnvironment = Join-Path $state 'main.env'
$nutritionEnvironment = Join-Path $state 'nutrition.env'
$demoEnvironment = Join-Path $state 'demo.env'
$configFile = Join-Path $state 'config.json'
$secret = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')

[IO.File]::WriteAllText($mainEnvironment, @"
APP_ENVIRONMENT=Development
APP_DOMAIN=demo.caresitter.test
POSTGRES_DB=caresitter
POSTGRES_USER=fixture
POSTGRES_PASSWORD=$secret
REDIS_PASSWORD=$secret
ConnectionStrings__CareSitter=Host=db;Database=caresitter;Username=fixture;Password=$secret
Redis__ConnectionString=redis:6379,password=$secret
Jwt__SecretKey=$secret
Jwt__Issuer=fixture
Jwt__Audience=fixture
Public__ApiBaseUrl=https://demo.caresitter.test
CARESITTER_ENV_FILE=$($mainEnvironment.Replace('\','/'))
"@)
[IO.File]::WriteAllText($nutritionEnvironment, @"
NUTRITION_ENABLED=false
NUTRITION_ASSESSMENTS_ENABLED=false
NUTRITION_RECOMMENDATIONS_ENABLED=false
NUTRITION_HEALTH_PARSER_ENABLED=false
"@)
[IO.File]::WriteAllText($demoEnvironment, @"
NUTRITION_DEMO_CATALOG_SHA256=$('a' * 64)
NUTRITION_DEMO_AUTHORIZATION_SHA256=$('b' * 64)
NUTRITION_DEMO_CORPUS_SHA256=$('c' * 64)
NUTRITION_DEMO_GRAPH_SHA256=$('d' * 64)
NUTRITION_DEMO_EXPECTED_RECIPES=60
NUTRITION_DEMO_PACKAGE_KEY=adult-baseline-p2a-v1-local-demo
NUTRITION_GEMINI_MODEL=gemini-3.5-flash-lite
NUTRITION_GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/
"@)

try {
    & docker compose --project-directory (Join-Path $repository 'deploy') `
        --env-file $mainEnvironment --env-file $nutritionEnvironment --env-file $demoEnvironment `
        -f (Join-Path $repository 'deploy/compose.yml') `
        -f (Join-Path $repository 'deploy/nutrition/compose.yml') `
        -f (Join-Path $repository 'deploy/nutrition/compose.demo.yml') `
        --profile nutrition-demo-seed --profile nutrition-smoke config --format json 1> $configFile 2> (Join-Path $state 'compose-errors.log')
    if ($LASTEXITCODE -ne 0) { throw "Demo Compose validation failed; inspect $state." }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    $nutrition = $config.services.nutrition
    $seed = $config.services.'nutrition-demo-catalog'
    $smoke = $config.services.'nutrition-smoke'
    if ($nutrition.environment.ASPNETCORE_ENVIRONMENT -ne 'Development') { throw 'Demo Nutrition must run in Development.' }
    foreach ($name in @('Nutrition__Enabled','Nutrition__AssessmentsEnabled','Nutrition__RecommendationsEnabled',
            'NutritionCatalog__LocalDemoEnabled','HealthParser__Enabled','MealGrounding__Enabled','MealRanking__Enabled')) {
        if ($nutrition.environment.$name -ne 'true') { throw "Demo flag is not enabled: $name" }
    }
    if ($nutrition.environment.MealGrounding__Mode -ne 'owner_authorized_graph_demo') { throw 'Demo grounding mode is incorrect.' }
    if ($nutrition.environment.MealGrounding__DemoGraphPath -ne '/demo/graph.candidate.json' -or
        $nutrition.environment.MealGrounding__DemoGraphSha256 -ne ('d' * 64) -or
        -not $nutrition.volumes.Where({ $_.target -eq '/demo/graph.candidate.json' -and $_.read_only })) {
        throw 'Demo graph must be hash-bound and mounted read-only.'
    }
    if ($nutrition.environment.HealthParser__ApiKey -or $nutrition.environment.MealRanking__ApiKey) { throw 'Gemini key must not be placed in environment variables.' }
    if ($nutrition.environment.HealthParser__ApiKeyFile -ne '/run/secrets/nutrition_gemini_key' -or
        $nutrition.environment.MealRanking__ApiKeyFile -ne '/run/secrets/nutrition_gemini_key') { throw 'Gemini key file binding is incorrect.' }
    if (-not $nutrition.secrets.Where({ $_.source -eq 'nutrition_gemini_key' })) { throw 'Gemini Docker secret is not mounted.' }
    if ($seed.ports) { throw 'Demo catalog seed job must not publish ports.' }
    if (-not ($seed.networks.PSObject.Properties.Name -contains 'nutrition-data') -or
        -not $config.networks.'nutrition-data'.internal) { throw 'Demo catalog seed job must stay on the private Nutrition network.' }
    if ($seed.environment.NUTRITION_DEMO_EXPECTED_RECIPES -ne '60') { throw 'Demo catalog recipe count is not locked.' }
    if ($seed.depends_on.'nutrition-db'.condition -ne 'service_healthy') { throw 'Demo seed job can start before the database is healthy.' }
    if ($smoke.environment.EXPECT_NUTRITION_DEMO_FEATURES -ne 'true') {
        throw 'Demo smoke must verify the Nutrition feature flags.'
    }
    Write-Output 'PASS: demo overlay enables guarded Nutrition features, private idempotent seed job, artifact mounts and file-based Gemini secret.'
    Write-Output 'This check validates Compose structure only; it does not contact Gemini or deploy a host.'
}
finally {
    Remove-Item -LiteralPath $mainEnvironment, $nutritionEnvironment, $demoEnvironment, $configFile -ErrorAction SilentlyContinue
}
