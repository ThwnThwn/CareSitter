[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5033'
)

$ErrorActionPreference = 'Stop'
$base = $BaseUrl.TrimEnd('/')

function Assert-Status {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Uri,
        [int]$ExpectedStatus = 200
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        $status = [int]$response.StatusCode
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw "$Name failed: $($_.Exception.Message)"
        }
        $status = [int]$_.Exception.Response.StatusCode
    }

    if ($status -ne $ExpectedStatus) {
        throw "$Name returned HTTP $status; expected $ExpectedStatus."
    }

    Write-Host "PASS  $Name ($status)"
}

Assert-Status -Name 'Liveness' -Uri "$base/health/live"
Assert-Status -Name 'Readiness' -Uri "$base/health/ready"
Assert-Status -Name 'Public service catalog' -Uri "$base/api/v1/services"
Assert-Status -Name 'Protected profile rejects anonymous access' -Uri "$base/api/v1/profile" -ExpectedStatus 401

$services = Invoke-RestMethod -Uri "$base/api/v1/services"
if (@($services).Count -lt 1) {
    throw 'Service catalog is empty.'
}

Write-Host "PASS  Service catalog contains $(@($services).Count) item(s)"

$swagger = Invoke-RestMethod -Uri "$base/swagger/v1/swagger.json"
$paths = @($swagger.paths.PSObject.Properties.Name)
if ($paths -contains '/api/v1/bookings/{id}/confirm-payment') {
    throw 'Unsafe direct payment confirmation endpoint is still exposed.'
}

Write-Host 'PASS  Direct customer payment confirmation is not exposed'
Write-Host 'Smoke test completed.'
