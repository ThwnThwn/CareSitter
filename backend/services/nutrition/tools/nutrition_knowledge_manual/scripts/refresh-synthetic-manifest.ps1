$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $toolRoot 'fixtures\catalog.synthetic.json'
$manifestPath = Join-Path $toolRoot 'config\source-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$source = $manifest.sources | Where-Object source_id -eq 'manual-graph-synthetic-catalog'
$hash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
$source.sha256 = $hash
$source.byte_size = (Get-Item -LiteralPath $fixture).Length
$source.revision_id = "manual-graph-synthetic-catalog@sha256:$($hash.Substring(0, 16))"
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8
