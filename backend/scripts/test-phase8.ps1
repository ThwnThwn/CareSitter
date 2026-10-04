[CmdletBinding()]
param(
    [string]$ContainerName,
    [ValidateRange(1, 10)]
    [int]$Repeat = 3,
    [string]$ArtifactsDirectory
)

# Reuse the isolated setup, published-port discovery, environment restoration
# and no-skipped-tests check. Keep the non-PostgreSQL booking flow tests too.
& (Join-Path $PSScriptRoot 'test-races.ps1') `
    -ContainerName $ContainerName -Repeat $Repeat -ArtifactsDirectory $ArtifactsDirectory `
    -Filter 'Category=PostgreSQL|FullyQualifiedName~BookingFlowTests'
