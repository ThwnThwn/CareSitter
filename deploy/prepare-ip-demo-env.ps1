[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PublicIp,
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
    throw 'The output environment already exists. It was not overwritten.'
}

$parsedIp = $null
if (-not [Net.IPAddress]::TryParse($PublicIp.Trim(), [ref]$parsedIp) -or
    $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
    throw 'PublicIp must be an IPv4 address without scheme, path or port.'
}
$PublicIp = $parsedIp.ToString()

function New-HexSecret([int]$bytes) {
    $hex = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes($bytes))
    return $hex.ToLowerInvariant()
}

$databasePassword = New-HexSecret 32
$redisPassword = New-HexSecret 32
$jwtSecret = New-HexSecret 48
$encryptionKey = New-HexSecret 32
$template = [IO.File]::ReadAllText((Join-Path $deployRoot 'demo-ip.env.example'))
$content = $template.Replace('REPLACE_WITH_PUBLIC_IPV4', $PublicIp)
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
    if ($LASTEXITCODE -ne 0) { throw 'Unable to protect the generated environment with mode 0600.' }
}
Write-Output "Created protected HTTP demo environment for $PublicIp without printing generated credentials."
