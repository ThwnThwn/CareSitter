param(
    [Parameter(Mandatory)][ValidateSet('Install', 'Remove')][string]$Action,
    [Parameter(Mandatory)][string[]]$Executables,
    [string]$RulePrefix = 'CareSitter-Nutrition-G0'
)

$ErrorActionPreference = 'Stop'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

foreach ($executable in $Executables) {
    $resolved = (Resolve-Path -LiteralPath $executable).Path
    $suffix = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash.Substring(0, 12)
    $ruleName = "$RulePrefix-$suffix"
    if ($Action -eq 'Install') {
        if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
            throw "Firewall rule already exists: $ruleName"
        }
        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -Program $resolved -Profile Any | Out-Null
        Write-Output "Installed $ruleName for $resolved"
    } else {
        Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        Write-Output "Removed $ruleName for $resolved"
    }
}
