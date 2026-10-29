[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$suffix = [Guid]::NewGuid().ToString('N')
$networkName = "caresitter-demo-seed-test-$suffix"
$databaseName = "caresitter-demo-seed-db-$suffix"
$imageName = 'caresitter-nutrition-ops-demo-test'
$fixturePassword = 'fixture-' + [Guid]::NewGuid().ToString('N')
$state = Join-Path $repository "backend/artifacts/nutrition-demo-seed-$suffix"
$preparedCatalog = Join-Path $state 'catalog.import.bundle.json'
$databaseStarted = $false
$networkCreated = $false

function Invoke-Docker([string[]]$arguments) {
    & docker @arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed: $($arguments[0])" }
}

try {
    New-Item -ItemType Directory -Path $state | Out-Null
    $catalogTool = Join-Path $repository 'backend/services/nutrition/tools/CareSitter.Nutrition.CatalogTool/CareSitter.Nutrition.CatalogTool.csproj'
    $sourceCatalog = Join-Path $repository 'backend/services/nutrition/catalog/drafts/adult-baseline-variety-demo.bundle.json'
    & dotnet run -c Release --project $catalogTool -- prepare-demo $sourceCatalog $preparedCatalog | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to prepare the fixture demo catalog.' }
    $catalogHash = (Get-FileHash -LiteralPath $preparedCatalog -Algorithm SHA256).Hash

    Invoke-Docker @('build','-q','-t',$imageName,'-f',
        (Join-Path $repository 'deploy/nutrition/Dockerfile.ops'),
        (Join-Path $repository 'deploy/nutrition'))
    Invoke-Docker @('network','create',$networkName)
    $networkCreated = $true
    Invoke-Docker @('run','-d','--name',$databaseName,'--network',$networkName,
        '-e',"POSTGRES_PASSWORD=$fixturePassword",'-e','POSTGRES_DB=nutrition',
        '-e','POSTGRES_USER=postgres','postgres:16')
    $databaseStarted = $true

    $ready = $false
    foreach ($attempt in 1..30) {
        & docker exec $databaseName pg_isready -U postgres -d nutrition *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'Fixture PostgreSQL did not become ready.' }

    $sqlDirectory = Join-Path $repository 'backend/init-db/nutrition-service'
    $migrationCommand = 'printf %s "$FIXTURE_PASSWORD" >/tmp/admin; printf %s "$FIXTURE_PASSWORD" >/tmp/app; export PGPASSWORD_FILE=/tmp/admin NUTRITION_APP_PASSWORD_FILE=/tmp/app; /ops/migrate.sh'
    Invoke-Docker @('run','--rm','--network',$networkName,
        '-e',"PGHOST=$databaseName",'-e','PGDATABASE=nutrition','-e','PGUSER=postgres',
        '-e',"FIXTURE_PASSWORD=$fixturePassword",'-e','NUTRITION_SQL_DIRECTORY=/sql',
        '-v',"${sqlDirectory}:/sql:ro",$imageName,'-c',$migrationCommand)

    $seedCommand = 'printf %s "$FIXTURE_PASSWORD" >/tmp/admin; export PGPASSWORD_FILE=/tmp/admin; /ops/seed-demo-catalog.sh'
    $seedArguments = @('run','--rm','--network',$networkName,
        '-e',"PGHOST=$databaseName",'-e','PGDATABASE=nutrition','-e','PGUSER=postgres',
        '-e',"FIXTURE_PASSWORD=$fixturePassword",'-e','NUTRITION_DEMO_CATALOG_PATH=/demo/catalog.json',
        '-e',"NUTRITION_DEMO_CATALOG_SHA256=$catalogHash",'-e','NUTRITION_DEMO_EXPECTED_RECIPES=60',
        '-e','NUTRITION_DEMO_PACKAGE_KEY=adult-baseline-p2a-v1-local-demo',
        '-v',"${preparedCatalog}:/demo/catalog.json:ro",$imageName,'-c',$seedCommand)
    Invoke-Docker $seedArguments
    Invoke-Docker $seedArguments

    $query = "select revision || ':' || jsonb_array_length(payload->'recipes') from nutrition.local_demo_catalog where package_key='adult-baseline-p2a-v1-local-demo'"
    $result = (& docker exec $databaseName psql -U postgres -d nutrition -Atc $query).Trim()
    if ($LASTEXITCODE -ne 0 -or $result -ne '1:60') {
        throw "Idempotent demo seed verification failed: $result"
    }
    Write-Output 'PASS: catalog preparation and two real PostgreSQL seed runs preserve revision 1 with 60 recipes.'
}
finally {
    if ($databaseStarted) { & docker rm -f $databaseName *> $null }
    if ($networkCreated) { & docker network rm $networkName *> $null }
    Remove-Item -LiteralPath $preparedCatalog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $state -Force -ErrorAction SilentlyContinue
}
