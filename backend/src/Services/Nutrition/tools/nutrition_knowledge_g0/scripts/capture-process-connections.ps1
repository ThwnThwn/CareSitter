param(
    [Parameter(Mandatory)][int[]]$ProcessIds,
    [Parameter(Mandatory)][string]$Output,
    [int]$DurationSeconds = 60
)

$ErrorActionPreference = 'Stop'
$target = [System.IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite capture: $target" }
$rows = [System.Collections.Generic.List[object]]::new()
for ($second = 0; $second -lt $DurationSeconds; $second++) {
    $capturedAt = [DateTime]::UtcNow.ToString('o')
    foreach ($processId in $ProcessIds) {
        Get-NetTCPConnection -OwningProcess $processId -ErrorAction SilentlyContinue | ForEach-Object {
            $rows.Add([ordered]@{
                captured_at_utc = $capturedAt
                process_id = $processId
                state = $_.State.ToString()
                local_address = $_.LocalAddress
                local_port = $_.LocalPort
                remote_address = $_.RemoteAddress
                remote_port = $_.RemotePort
            })
        }
    }
    Start-Sleep -Seconds 1
}
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $target -Encoding utf8NoBOM
Write-Output $target
