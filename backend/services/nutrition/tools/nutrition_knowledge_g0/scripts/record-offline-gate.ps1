param(
    [Parameter(Mandatory)][string]$FreezeContentSha256,
    [Parameter(Mandatory)][string]$PythonExecutable,
    [Parameter(Mandatory)][string[]]$OllamaExecutables,
    [Parameter(Mandatory)][bool]$AdaptersDisabled,
    [Parameter(Mandatory)][bool]$OllamaRulesApplied,
    [Parameter(Mandatory)][bool]$NoPipelineOutboundAttempts,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = (Resolve-Path (Join-Path $moduleRoot '..\..\..\..\..')).Path
$artifactRoot = Join-Path $workspaceRoot 'backend\artifacts\nutrition-knowledge-local'
$outputRoot = Join-Path $artifactRoot 'offline-gate'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$pythonBlocked = $false
& $PythonExecutable -c "import urllib.request; urllib.request.urlopen('https://example.com', timeout=3)" 2>$null
if ($LASTEXITCODE -ne 0) {
    $pythonBlocked = $true
}

$evidenceFiles = Get-ChildItem -LiteralPath $EvidenceDirectory -File | ForEach-Object {
    [ordered]@{
        name = $_.Name
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        byte_size = $_.Length
    }
}
$allExecutablesExist = (Test-Path -LiteralPath $PythonExecutable) -and -not ($OllamaExecutables | Where-Object { -not (Test-Path -LiteralPath $_) })
$passed = $AdaptersDisabled -and $OllamaRulesApplied -and $NoPipelineOutboundAttempts -and $pythonBlocked -and $allExecutablesExist
$report = [ordered]@{
    schema_version = 1
    freeze_content_sha256 = $FreezeContentSha256
    passed = $passed
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    adapters_disabled = $AdaptersDisabled
    ollama_rules_applied = $OllamaRulesApplied
    no_pipeline_outbound_attempts = $NoPipelineOutboundAttempts
    python_positive_control_blocked = $pythonBlocked
    executables = @($PythonExecutable) + $OllamaExecutables
    evidence = @($evidenceFiles)
    note = 'This recorder does not disable adapters or create firewall rules; those privileged steps must be evidenced separately.'
}
$target = Join-Path $outputRoot "$FreezeContentSha256.json"
if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite offline gate artifact: $target" }
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $target -Encoding utf8NoBOM
$report | ConvertTo-Json -Depth 6
