[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5033',
    [string]$AdminEmail,
    [string]$CustomerEmail,
    [string]$CaregiverEmail,
    [string]$TestPassword
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

function Assert-RoleLogin {
    param(
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][string]$Role
    )

    $body = @{
        email = $Email
        password = $Password
        requiredRole = $Role
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod `
            -Uri "$base/api/v1/auth/login/password" `
            -Method Post `
            -ContentType 'application/json' `
            -Body $body
    }
    catch {
        $details = $_.Exception.Message
        if ($null -ne $_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = [System.IO.StreamReader]::new($stream)
                $responseBody = $reader.ReadToEnd()
                if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                    $details = "$details Response: $responseBody"
                }
            }
            catch {
                # Keep the original HTTP error when the response body cannot be read.
            }
        }
        throw "Seed account login failed for role $Role ($Email): $details"
    }

    if ([string]::IsNullOrWhiteSpace($response.accessToken) -or
        $response.roles -notcontains $Role) {
        throw "Seed account login returned an invalid token or roles for $Role ($Email)."
    }

    Write-Host "PASS  Seed account login for $Role ($Email)"
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

if (-not [string]::IsNullOrWhiteSpace($TestPassword)) {
    if ([string]::IsNullOrWhiteSpace($AdminEmail) -or
        [string]::IsNullOrWhiteSpace($CustomerEmail) -or
        [string]::IsNullOrWhiteSpace($CaregiverEmail)) {
        throw 'AdminEmail, CustomerEmail and CaregiverEmail are required when TestPassword is provided.'
    }

    Assert-RoleLogin -Email $AdminEmail -Password $TestPassword -Role 'ADMIN'
    Assert-RoleLogin -Email $CustomerEmail -Password $TestPassword -Role 'CUSTOMER'
    Assert-RoleLogin -Email $CaregiverEmail -Password $TestPassword -Role 'CAREGIVER'
}

Write-Host 'Smoke test completed.'
