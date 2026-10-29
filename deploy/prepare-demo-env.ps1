[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Domain,
    [string]$CustomerOrigin,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$deployRoot = (Resolve-Path $PSScriptRoot).Path
if (-not $OutputPath) { $OutputPath = Join-Path $deployRoot '.env' }
$output = [IO.Path]::GetFullPath($OutputPath)
$deployPrefix = $deployRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($deployPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The generated environment must stay below deploy/.'
}
if (Test-Path -LiteralPath $output) {
    throw 'deploy/.env already exists. It was not overwritten.'
}

$Domain = $Domain.Trim().ToLowerInvariant()
if ($Domain -notmatch '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
    throw 'Domain must be a DNS hostname without scheme, path or port.'
}
if ([string]::IsNullOrWhiteSpace($CustomerOrigin)) { $CustomerOrigin = "https://$Domain" }
$parsedCustomerOrigin = $null
if (-not [Uri]::TryCreate($CustomerOrigin, [UriKind]::Absolute, [ref]$parsedCustomerOrigin) -or
    -not $CustomerOrigin.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'CustomerOrigin must be an absolute HTTPS origin.'
}
$customerUri = $parsedCustomerOrigin
if ($customerUri.PathAndQuery -ne '/' -or $customerUri.Fragment) {
    throw 'CustomerOrigin must not contain a path, query or fragment.'
}
$CustomerOrigin = $CustomerOrigin.TrimEnd('/')

function New-HexSecret([int]$bytes) {
    $hex = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes($bytes))
    return $hex.ToLowerInvariant()
}

$databasePassword = New-HexSecret 32
$redisPassword = New-HexSecret 32
$jwtSecret = New-HexSecret 48
$encryptionKey = New-HexSecret 32
$template = [IO.File]::ReadAllText((Join-Path $deployRoot 'demo.env.example'))
$content = $template.Replace('REPLACE_WITH_DEMO_DOMAIN', $Domain)
$content = $content.Replace('REPLACE_WITH_CUSTOMER_APP_ORIGIN', $CustomerOrigin)
$content = $content.Replace('REPLACE_WITH_RANDOM_DATABASE_PASSWORD', $databasePassword)
$content = $content.Replace('REPLACE_WITH_RANDOM_REDIS_PASSWORD', $redisPassword)
$content = $content.Replace('REPLACE_WITH_RANDOM_JWT_SECRET_AT_LEAST_32_CHARACTERS', $jwtSecret)
$content = $content.Replace('REPLACE_WITH_RANDOM_ENCRYPTION_KEY_AT_LEAST_32_CHARACTERS', $encryptionKey)
if ($content -match 'REPLACE_WITH_[A-Z0-9_]+') {
    throw 'The generated demo environment still contains a placeholder.'
}
[IO.File]::WriteAllText($output, $content.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
if (-not $IsWindows) {
    & chmod 600 $output
    if ($LASTEXITCODE -ne 0) { throw 'Unable to protect deploy/.env with mode 0600.' }
}
Write-Output "Created protected demo environment for $Domain without printing generated credentials."
