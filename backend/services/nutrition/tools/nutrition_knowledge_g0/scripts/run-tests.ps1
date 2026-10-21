$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $moduleRoot 'src'
$env:PYTHONPATH = $sourceRoot

python -m unittest discover -s (Join-Path $moduleRoot 'tests') -v
