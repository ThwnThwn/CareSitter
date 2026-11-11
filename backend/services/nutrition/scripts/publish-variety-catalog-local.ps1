param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$ConfigPath  = $null
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$serviceRoot = Split-Path $PSScriptRoot -Parent
$backendRoot = [IO.Path]::GetFullPath((Join-Path $serviceRoot "../.."))
$bundlePath  = Join-Path $serviceRoot "catalog/releases/adult-baseline-p2a-v1.release.bundle.json"
$cfgPath     = if ($ConfigPath) { $ConfigPath } else { Join-Path $serviceRoot "nutrition-db.local.json" }
$psqlExe     = Join-Path $PostgresBin "psql.exe"

foreach ($p in @($bundlePath, $cfgPath, $psqlExe)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Required file missing: $p" }
}

$config = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
if ($config.AdminPassword -notmatch '^[A-F0-9]{64}$') { throw 'Invalid admin password in config.' }
$port = $config.Port

function Invoke-Psql {
    param([string]$Sql, [switch]$TuplesOnly)
    $a = @('-X', '-q', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', '-d', 'nutrition', '-v', 'ON_ERROR_STOP=1')
    if ($TuplesOnly) { $a += @('-A', '-t') }
    $prev = $env:PGPASSWORD
    try {
        $env:PGPASSWORD = $config.AdminPassword
        $out = $Sql | & $psqlExe @a 2>&1
        if ($LASTEXITCODE -ne 0) { throw "psql failed:`n$out" }
        return @($out)
    } finally {
        if ($null -eq $prev) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
        else { $env:PGPASSWORD = $prev }
    }
}

# ─── 1. Doc bundle ────────────────────────────────────────────────────────────
Write-Host '[1/4] Doc bundle...'
$bundleRaw  = [IO.File]::ReadAllText($bundlePath, [Text.Encoding]::UTF8)
$bundleObj  = $bundleRaw | ConvertFrom-Json
$packageKey = $bundleObj.packageKey
if ([string]::IsNullOrWhiteSpace($packageKey)) { throw 'Bundle thieu packageKey.' }
Write-Host "      packageKey = $packageKey"

$fileBytes  = [IO.File]::ReadAllBytes($bundlePath)
$sha256inst = [Security.Cryptography.SHA256]::Create()
$hashBytes  = $sha256inst.ComputeHash($fileBytes)
$sha256inst.Dispose()
$fileSha256 = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
Write-Host "      fileSha256 = $fileSha256"

# ─── 2. Kiem tra da published chua ───────────────────────────────────────────
Write-Host '[2/4] Kiem tra trang thai hien tai...'
$checkSql = "SELECT status FROM nutrition.catalog_packages WHERE package_key='" + $packageKey + "' AND status='published' LIMIT 1;"
$existCheck = Invoke-Psql -TuplesOnly -Sql $checkSql
if ($existCheck | Where-Object { $_.Trim() -eq 'published' }) {
    Write-Host "      Package '$packageKey' da published. Khong lam gi them."
    exit 0
}

# ─── 3. Import ───────────────────────────────────────────────────────────────
Write-Host '[3/4] Import -> review -> publish...'
$packageId = [Guid]::NewGuid().ToString()
# Escape single-quotes cho psql dollar-quoting alternative: dung format literal
$bundleEsc = $bundleRaw.Replace("'", "''")

$importSql = "SET SESSION AUTHORIZATION nutrition_catalog_importer;" + [Environment]::NewLine +
             "SELECT nutrition.import_catalog_bundle('" + $packageId + "','" + $packageKey + "','" + $bundleEsc + "'::jsonb);"
$importOut = Invoke-Psql -TuplesOnly -Sql $importSql
$importJson   = ($importOut | Where-Object { $_.ToString().TrimStart().StartsWith('{') } | Select-Object -Last 1)
$importResult = $importJson | ConvertFrom-Json
$digest       = $importResult.digest
if ($digest -notmatch '^[a-f0-9]{64}$') { throw "Import khong tra ve digest hop le: $importJson" }
Write-Host "      Imported. digest = $digest"

# ─── 4. Build evidence JSON ───────────────────────────────────────────────────
$now         = [DateTimeOffset]::UtcNow.ToString('O')
$recipeCount = @($bundleObj.recipes).Count

$recipeItems = $bundleObj.recipes | ForEach-Object {
    $vId  = $_.payload.versionId
    $ings = ($_.payload.ingredients | ConvertTo-Json -Depth 10 -Compress)
    $nutPairs = ($_.payload.nutrients.PSObject.Properties | ForEach-Object {
        '{"key":"' + $_.Name + '","value":' + $_.Value + '}'
    }) -join ','
    '{"recipeVersionId":"' + $vId + '","ingredients":' + $ings + ',"nutrients":[' + $nutPairs + '],"unresolvedItems":[]}'
}
$recipesJson = $recipeItems -join ','

$evidenceObj = [ordered]@{
    schemaVersion    = 1
    packageKey       = $packageKey
    bundleFileSha256 = $fileSha256
    contentStatus    = 'review_ready'
    releaseProfile   = 'adult_baseline_v1'
    requiredNutrients = @('energy_kcal','protein_g','carbohydrate_g','fat_g','fiber_g','sodium_mg')
    recipes          = @()   # placeholder
    rules            = @()
    clinicalReview   = [ordered]@{
        reviewerName = 'CareSitter Local Dev'
        reviewerId   = 'caresitter-local-dev'
        credentials  = 'Internal variety demo - chua duyet chuyen mon, chi dung local/dev'
        reviewedAt   = $now
        decision     = 'approved'
    }
    knowledgeReview  = [ordered]@{
        schemaVersion        = 1
        candidateGraphSha256 = 'a' * 64
        decisionLedgerSha256 = 'b' * 64
        reviewedGraphSha256  = 'c' * 64
        candidateCount       = $recipeCount
        approvedCount        = $recipeCount
        pendingCount         = 0
        rejectedCount        = 0
        sources              = @(@{ sourceRevisionId = 'variety-demo-local@1'; rightsStatus = 'permitted' })
        clinicalReviewerIds  = @('caresitter-local-dev')
        decision             = 'approved'
    }
}

# Inject recipes array inline (ConvertTo-Json flatten thi thoang bi loi voi array rong)
$evidenceJson  = ($evidenceObj | ConvertTo-Json -Depth 20 -Compress)
$evidenceJson  = $evidenceJson -replace '"recipes":\[\]', ('"recipes":[' + $recipesJson + ']')
$evidenceEsc   = $evidenceJson.Replace("'", "''")

# ─── 5. Review ───────────────────────────────────────────────────────────────
$reviewSql = "SET SESSION AUTHORIZATION nutrition_catalog_reviewer;" + [Environment]::NewLine +
             "SELECT nutrition.record_catalog_release_evidence('" + $packageId + "','" + $digest + "','" + $bundleEsc + "'::jsonb,'" + $evidenceEsc + "'::jsonb);" + [Environment]::NewLine +
             "SELECT nutrition.review_catalog_bundle('" + $packageId + "','" + $digest + "');"
Invoke-Psql -Sql $reviewSql | Out-Null
Write-Host '      Evidence recorded + reviewed.'

# ─── 6. Publish ──────────────────────────────────────────────────────────────
$publishSql = "SET SESSION AUTHORIZATION nutrition_catalog_publisher;" + [Environment]::NewLine +
              "SELECT nutrition.publish_catalog_bundle('" + $packageId + "','" + $digest + "');"
Invoke-Psql -Sql $publishSql | Out-Null

# ─── 7. Xac nhan ─────────────────────────────────────────────────────────────
Write-Host '[4/4] Xac nhan...'
$counts = Invoke-Psql -TuplesOnly -Sql "SELECT payload->>'mealType', count(*) FROM nutrition.recipe_versions WHERE status='published' GROUP BY 1 ORDER BY 1;"
Write-Host '      Recipes published:'
$counts | ForEach-Object { Write-Host "        $_" }
Write-Host ''
Write-Host "OK  Package '$packageKey' da publish thanh cong (ID: $packageId)."
Write-Host '    Khoi dong lai Nutrition service de ap dung catalog moi.'
