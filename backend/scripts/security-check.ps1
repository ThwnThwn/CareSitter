[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendRoot

Push-Location $backendRoot
try {
    & dotnet test CareSitter.sln --nologo --filter 'FullyQualifiedName~SecurityContractTests'
    if ($LASTEXITCODE -ne 0) { throw 'Backend security contract tests failed.' }

    $auditOutput = & dotnet list CareSitter.sln package --vulnerable --include-transitive 2>&1
    $auditOutput | Write-Host
    if ($LASTEXITCODE -ne 0) { throw 'NuGet vulnerability audit failed.' }
    if ($auditOutput -match '(?im)^\s*>\s+.+\s+(Critical|High)\s+') {
        throw 'NuGet audit found a Critical or High vulnerability.'
    }
}
finally {
    Pop-Location
}

Push-Location (Join-Path $repoRoot 'frontend/admin-web')
try {
    & npm audit --omit=dev --audit-level=high
    if ($LASTEXITCODE -ne 0) { throw 'Admin web dependency audit failed.' }
}
finally {
    Pop-Location
}

Push-Location (Join-Path $repoRoot 'frontend/caregiver-app')
try {
    & flutter test test/features/shifts/caregiver_shift_action_policy_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Caregiver security workflow tests failed.' }
}
finally {
    Pop-Location
}

Push-Location $repoRoot
try {
    $secretMatches = & git grep -n -I -E `
        'dev-only-change-me|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9]{20,}' `
        -- backend frontend 2>$null
    if ($LASTEXITCODE -eq 0 -and $secretMatches) {
        $secretMatches | Write-Host
        throw 'Tracked source contains a prohibited secret pattern.'
    }
}
finally {
    Pop-Location
}

Write-Host 'Security checks passed.'
