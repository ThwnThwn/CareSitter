[CmdletBinding()]
param(
    [string]$SourceEnvironmentFile,
    [switch]$SkipFirebase
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$deployRoot = (Resolve-Path (Join-Path $repository 'deploy')).Path
if (-not $SourceEnvironmentFile) { $SourceEnvironmentFile = Join-Path $repository 'backend/.env' }
$SourceEnvironmentFile = (Resolve-Path -LiteralPath $SourceEnvironmentFile).Path

function Read-EnvironmentFile([string]$path) {
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^\s*([^#=\s]+)=(.*)$') {
            $values[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $values
}

function Resolve-ConfiguredPath([string]$value, [string]$name) {
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing $name in $SourceEnvironmentFile." }
    $candidate = if ([IO.Path]::IsPathFullyQualified($value)) { $value } else { Join-Path $repository $value }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "$name does not point to a readable file." }
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-Sha256([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-ExpectedHash([string]$path, [string]$expected, [string]$name) {
    if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw "$name SHA-256 is missing or invalid." }
    $actual = Get-Sha256 $path
    if ($actual -ne $expected.ToUpperInvariant()) { throw "$name SHA-256 does not match the source environment." }
    return $actual
}

function Assert-UnderDeploy([string]$path) {
    $full = [IO.Path]::GetFullPath($path)
    $prefix = $deployRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Generated deployment files must stay below deploy/.'
    }
    return $full
}

function Copy-VerifiedFile([string]$source, [string]$destination, [string]$expectedHash) {
    $destination = Assert-UnderDeploy $destination
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    if ((Get-Sha256 $destination) -ne $expectedHash) { throw 'Copied deployment artifact failed verification.' }
}

function Write-ProtectedFile([string]$path, [string]$content) {
    $path = Assert-UnderDeploy $path
    $parent = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    if (Test-Path -LiteralPath $path) {
        $existing = [IO.File]::ReadAllText($path)
        if ($existing -cne $content) { throw "Protected file already exists with different content: $path" }
        return
    }
    [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
}

$configuration = Read-EnvironmentFile $SourceEnvironmentFile
if ($configuration['MealGrounding__Mode'] -ne 'owner_authorized_graph_demo') {
    throw 'Configure owner_authorized_graph_demo before preparing the GraphRAG demo runtime.'
}
$authorization = Resolve-ConfiguredPath $configuration['MealGrounding__DemoAuthorizationPath'] 'MealGrounding__DemoAuthorizationPath'
$corpus = Resolve-ConfiguredPath $configuration['MealGrounding__CorpusPath'] 'MealGrounding__CorpusPath'
$graph = Resolve-ConfiguredPath $configuration['MealGrounding__DemoGraphPath'] 'MealGrounding__DemoGraphPath'
$authorizationHash = Assert-ExpectedHash $authorization $configuration['MealGrounding__DemoAuthorizationSha256'] 'Demo authorization'
$corpusHash = Assert-ExpectedHash $corpus $configuration['MealGrounding__CorpusSha256'] 'Demo corpus'
$graphHash = Assert-ExpectedHash $graph $configuration['MealGrounding__DemoGraphSha256'] 'Demo graph'
$authorizationPayload = Get-Content -LiteralPath $authorization -Raw | ConvertFrom-Json
if ($authorizationPayload.mode -ne 'owner_authorized_graph_demo' -or
    $authorizationPayload.authorized_environment -ne 'Development' -or
    $authorizationPayload.authorized_use -ne 'academic_demo' -or $authorizationPayload.owner_accepted -ne $true -or
    $authorizationPayload.independent_clinical_review -ne $false -or
    $authorizationPayload.production_release_authorized -ne $false -or
    $authorizationPayload.graph_review_status -ne 'candidate_not_independently_reviewed' -or
    $authorizationPayload.graph_sha256 -ne $graphHash -or $authorizationPayload.corpus_sha256 -ne $corpusHash) {
    throw 'GraphRAG demo authorization does not match the requested use and artifact hashes.'
}

$catalog = Join-Path $repository 'backend/services/nutrition/catalog/drafts/adult-baseline-variety-demo.bundle.json'
if (-not (Test-Path -LiteralPath $catalog -PathType Leaf)) { throw 'The 60-meal demo catalog bundle is missing.' }
$catalogPayload = Get-Content -LiteralPath $catalog -Raw | ConvertFrom-Json
if ($catalogPayload.packageKey -ne 'adult-baseline-p2a-v1' -or $catalogPayload.recipes.Count -ne 60) {
    throw 'The demo catalog must contain the expected package key and exactly 60 recipes.'
}
$apiKeys = @(@($configuration['MealRanking__ApiKey'], $configuration['HealthParser__ApiKey']) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($apiKeys.Count -ne 1 -or $apiKeys[0].Length -lt 20 -or $apiKeys[0].Length -gt 512) {
    throw 'Configure one shared Gemini API key for MealRanking and HealthParser before packaging.'
}

$runtime = Join-Path $deployRoot 'runtime/nutrition'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$preparedCatalog = Join-Path $runtime 'catalog.import.bundle.json'
$catalogTool = Join-Path $repository 'backend/services/nutrition/tools/CareSitter.Nutrition.CatalogTool/CareSitter.Nutrition.CatalogTool.csproj'
& dotnet run -c Release --project $catalogTool -- prepare-demo $catalog $preparedCatalog
if ($LASTEXITCODE -ne 0) { throw 'CatalogTool failed to prepare the deployment-safe local demo bundle.' }
$preparedPayload = Get-Content -LiteralPath $preparedCatalog -Raw | ConvertFrom-Json
if ($preparedPayload.packageKey -ne 'adult-baseline-p2a-v1-local-demo' -or $preparedPayload.recipes.Count -ne 60 -or
    @($preparedPayload.recipes | Where-Object { -not $_.payload.name.StartsWith('[DEMO] ') }).Count -ne 0) {
    throw 'Prepared demo catalog does not satisfy the local-demo boundary.'
}
$catalogHash = Get-Sha256 $preparedCatalog
Copy-VerifiedFile $authorization (Join-Path $runtime 'retrieval-authorization.json') $authorizationHash
Copy-VerifiedFile $corpus (Join-Path $runtime 'corpus.jsonl') $corpusHash
Copy-VerifiedFile $graph (Join-Path $runtime 'graph.candidate.json') $graphHash
Write-ProtectedFile (Join-Path $deployRoot 'secrets/nutrition/gemini-api-key') $apiKeys[0]

if (-not $SkipFirebase) {
    $firebase = Resolve-ConfiguredPath $configuration['Firebase__ServiceAccountPath'] 'Firebase__ServiceAccountPath'
    $firebaseDestination = Join-Path $deployRoot 'secrets/firebase-service-account.json'
    $firebaseBytes = [IO.File]::ReadAllBytes($firebase)
    $firebaseText = [Text.Encoding]::UTF8.GetString($firebaseBytes)
    Write-ProtectedFile $firebaseDestination $firebaseText
}

$model = if ($configuration['MealRanking__Model']) { $configuration['MealRanking__Model'] } else { 'gemini-3.5-flash-lite' }
$baseUrl = if ($configuration['MealRanking__BaseUrl']) { $configuration['MealRanking__BaseUrl'] } else { 'https://generativelanguage.googleapis.com/v1beta/' }
$generated = @"
# Generated by deploy/nutrition/prepare-demo-runtime.ps1; contains hashes, not secrets.
NUTRITION_DEMO_PACKAGE_KEY=adult-baseline-p2a-v1-local-demo
NUTRITION_DEMO_EXPECTED_RECIPES=60
NUTRITION_DEMO_CATALOG_SHA256=$catalogHash
NUTRITION_DEMO_AUTHORIZATION_SHA256=$authorizationHash
NUTRITION_DEMO_CORPUS_SHA256=$corpusHash
NUTRITION_DEMO_GRAPH_SHA256=$graphHash
NUTRITION_DEMO_GROUNDING_TOP_K=5
NUTRITION_GEMINI_MODEL=$model
NUTRITION_GEMINI_BASE_URL=$baseUrl
NUTRITION_MEAL_RANKING_TIMEOUT_SECONDS=20
NUTRITION_MEAL_RANKING_MAX_OUTPUT_TOKENS=1536
NUTRITION_MEAL_RANKING_MAX_ATTEMPTS=2
NUTRITION_MEAL_RANKING_MAX_CONCURRENCY=4
NUTRITION_MEAL_RANKING_DAILY_BUDGET=1000
NUTRITION_MEAL_RANKING_MAX_RESPONSE_BYTES=131072
NUTRITION_MEAL_RANKING_MAX_CANDIDATE_SETS=12
"@.Replace("`r`n", "`n")
$demoEnvironment = Join-Path $deployRoot 'nutrition.demo.env'
[IO.File]::WriteAllText((Assert-UnderDeploy $demoEnvironment), $generated, [Text.UTF8Encoding]::new($false))

$nutritionEnvironment = Join-Path $deployRoot 'nutrition.env'
if (-not (Test-Path -LiteralPath $nutritionEnvironment)) {
    Copy-Item -LiteralPath (Join-Path $deployRoot 'nutrition.env.example') -Destination $nutritionEnvironment
}

Write-Output "Prepared Nutrition demo runtime: catalog=60, catalogSha256=$catalogHash"
Write-Output 'Gemini credential was prepared in ignored deploy/secrets without printing its value.'
if (-not $SkipFirebase) { Write-Output 'Firebase credential was prepared in ignored deploy/secrets.' }
Write-Output 'On the Linux server, set deploy env files to 0600, then run deploy/nutrition/deploy-demo.sh.'
