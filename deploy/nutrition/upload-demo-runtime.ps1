[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$RemoteRepository
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if ($Target -notmatch '^(?:[a-zA-Z0-9._-]+@)?[a-zA-Z0-9._-]+$') {
    throw 'Target must be an SSH host or user@host without shell characters.'
}
if ($RemoteRepository -notmatch '^/[a-zA-Z0-9._/-]+$' -or $RemoteRepository.Contains('..')) {
    throw 'RemoteRepository must be a safe absolute Linux path.'
}
$RemoteRepository = $RemoteRepository.TrimEnd('/')

$runtimeFiles = @(
    'deploy/runtime/nutrition/catalog.import.bundle.json',
    'deploy/runtime/nutrition/retrieval-authorization.json',
    'deploy/runtime/nutrition/corpus.jsonl',
    'deploy/runtime/nutrition/graph.candidate.json'
)
$secretFiles = @(
    'deploy/secrets/nutrition/gemini-api-key',
    'deploy/secrets/firebase-service-account.json'
)
$environmentFiles = @('deploy/.env','deploy/nutrition.demo.env','deploy/nutrition.env')
foreach ($relative in $runtimeFiles + $secretFiles + $environmentFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repository $relative) -PathType Leaf)) {
        throw "Missing packaged deployment file: $relative"
    }
}

$remoteRuntime = "$RemoteRepository/deploy/runtime/nutrition"
$remoteNutritionSecrets = "$RemoteRepository/deploy/secrets/nutrition"
$remoteSecrets = "$RemoteRepository/deploy/secrets"
& ssh $Target "mkdir -p '$remoteRuntime' '$remoteNutritionSecrets' '$remoteSecrets' && chmod 700 '$RemoteRepository/deploy/secrets' '$remoteNutritionSecrets'"
if ($LASTEXITCODE -ne 0) { throw 'Unable to prepare protected remote deployment directories.' }

foreach ($relative in $runtimeFiles) {
    & scp (Join-Path $repository $relative) "${Target}:$remoteRuntime/"
    if ($LASTEXITCODE -ne 0) { throw "Unable to upload $relative." }
}
& scp (Join-Path $repository $secretFiles[0]) "${Target}:$remoteNutritionSecrets/gemini-api-key"
if ($LASTEXITCODE -ne 0) { throw 'Unable to upload the Gemini secret.' }
& scp (Join-Path $repository $secretFiles[1]) "${Target}:$remoteSecrets/firebase-service-account.json"
if ($LASTEXITCODE -ne 0) { throw 'Unable to upload the Firebase credential.' }
foreach ($relative in $environmentFiles) {
    & scp (Join-Path $repository $relative) "${Target}:$RemoteRepository/deploy/"
    if ($LASTEXITCODE -ne 0) { throw "Unable to upload $relative." }
}

& ssh $Target "chmod 600 '$RemoteRepository/deploy/.env' '$RemoteRepository/deploy/nutrition.demo.env' '$RemoteRepository/deploy/nutrition.env' && chmod 444 '$remoteSecrets/firebase-service-account.json' && chmod 400 '$remoteNutritionSecrets/gemini-api-key' && chmod 644 '$remoteRuntime/'*"
if ($LASTEXITCODE -ne 0) { throw 'Unable to apply protected permissions to uploaded demo runtime files.' }
Write-Output "Uploaded the ignored Nutrition runtime and credentials to $Target without printing secret values."
