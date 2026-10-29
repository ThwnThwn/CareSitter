[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AppPublicIp,
    [Parameter(Mandatory)][string]$DataPrivateIp,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$deployRoot = (Resolve-Path $PSScriptRoot).Path
if (-not $OutputPath) { $OutputPath = Join-Path $deployRoot '.env.split' }
$output = [IO.Path]::GetFullPath($OutputPath)
$deployPrefix = $deployRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($deployPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The generated environment must stay below deploy/.'
}
if (Test-Path -LiteralPath $output) {
    throw 'The output environment already exists. It was not overwritten.'
}

function Assert-IPv4([string]$value, [string]$name) {
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($value.Trim(), [ref]$parsed) -or
        $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "$name must be an IPv4 address without scheme, path or port."
    }
    return $parsed.ToString()
}

function New-HexSecret([int]$bytes) {
    $hex = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes($bytes))
    return $hex.ToLowerInvariant()
}

$appIp = Assert-IPv4 $AppPublicIp 'AppPublicIp'
$dataIp = Assert-IPv4 $DataPrivateIp 'DataPrivateIp'
if (-not $dataIp.StartsWith('10.')) {
    throw 'DataPrivateIp must be the data VM private VCN address (expected 10.x.x.x), not its public IP.'
}

$databasePassword = New-HexSecret 32
$redisPassword = New-HexSecret 32
$jwtSecret = New-HexSecret 48
$encryptionKey = New-HexSecret 32
$template = [IO.File]::ReadAllText((Join-Path $deployRoot 'demo-split.env.example'))
$content = $template.Replace('REPLACE_WITH_APP_PUBLIC_IPV4', $appIp)
$content = $content.Replace('REPLACE_WITH_DATA_PRIVATE_IPV4', $dataIp)
$content = $content.Replace('REPLACE_WITH_RANDOM_DATABASE_PASSWORD', $databasePassword)
$content = $content.Replace('REPLACE_WITH_RANDOM_REDIS_PASSWORD', $redisPassword)
$content = $content.Replace('REPLACE_WITH_RANDOM_JWT_SECRET_AT_LEAST_32_CHARACTERS', $jwtSecret)
$content = $content.Replace('REPLACE_WITH_RANDOM_ENCRYPTION_KEY_AT_LEAST_32_CHARACTERS', $encryptionKey)
if ($content -match 'REPLACE_WITH_[A-Z0-9_]+') {
    throw 'The generated split-demo environment still contains a placeholder.'
}
[IO.File]::WriteAllText($output, $content.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
if (-not $IsWindows) {
    & chmod 600 $output
    if ($LASTEXITCODE -ne 0) { throw 'Unable to protect the generated environment with mode 0600.' }
}
Write-Output "Created split HTTP demo environment for app $appIp and private data host $dataIp without printing generated credentials."
