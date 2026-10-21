param(
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $PSScriptRoot
$env:PYTHONPATH = Join-Path $toolRoot 'src'
& $Python -m unittest discover -s (Join-Path $toolRoot 'tests') -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Python -m compileall -q (Join-Path $toolRoot 'src') (Join-Path $toolRoot 'tests')
exit $LASTEXITCODE
