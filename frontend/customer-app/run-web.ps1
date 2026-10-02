param(
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Device = 'chrome',
    [ValidateRange(1024, 65535)]
    [int]$Port = 7357,
    [string]$BaseUrl = 'http://localhost:5033/api/v1',
    [string]$GoogleWebClientId = $env:GOOGLE_WEB_CLIENT_ID,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

# Read only the public OAuth audience; never pass the backend .env to Flutter.
if ([string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
    $backendEnv = Join-Path $PSScriptRoot '../../backend/.env'
    if (Test-Path -LiteralPath $backendEnv) {
        foreach ($line in Get-Content -LiteralPath $backendEnv) {
            if ($line -match '^\s*Google__ClientId\s*=\s*(.+?)\s*$') {
                $GoogleWebClientId = $Matches[1].Trim().Trim('"', "'")
                break
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GoogleWebClientId) -or
    $GoogleWebClientId.Trim() -notmatch '^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') {
    throw 'Set Google__ClientId in backend/.env or pass -GoogleWebClientId with the backend OAuth Web client ID.'
}

Write-Host "Customer app: http://localhost:$Port"
Write-Host 'Google Web Client ID loaded. Register this exact localhost origin in Google Cloud.'
if ($CheckOnly) { return }

Push-Location $PSScriptRoot
try {
    & flutter run -d $Device --web-hostname localhost --web-port $Port `
        "--dart-define=BASE_URL=$BaseUrl" `
        "--dart-define=GOOGLE_WEB_CLIENT_ID=$($GoogleWebClientId.Trim())"
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
