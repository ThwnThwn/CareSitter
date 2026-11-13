<#
.SYNOPSIS
Runs a local Nutrition M4 prototype query with the verified r2 artifacts.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Question,

    [ValidateSet('keyword', 'vector', 'hybrid')]
    [string]$Strategy = 'hybrid',

    [ValidateRange(1, 10)]
    [int]$TopK = 5
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$artifactRoot = Join-Path $repoRoot 'backend/artifacts/nutrition-knowledge-local'
$python = Join-Path $artifactRoot 'venv/Scripts/python.exe'
$queryScript = Join-Path $PSScriptRoot 'nutrition-query-local.py'
$endpoint = 'http://127.0.0.1:11434/api/tags'

if (-not (Test-Path -LiteralPath $python)) {
    throw "Thiếu Python venv local: $python"
}

function Test-OllamaReady {
    try {
        $null = Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-OllamaReady)) {
    $candidates = @(
        (Join-Path $artifactRoot 'ollama-app/ollama.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs/Ollama/ollama.exe')
    )
    $ollama = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $ollama) {
        $command = Get-Command ollama -ErrorAction SilentlyContinue
        if ($command) { $ollama = $command.Source }
    }
    if (-not $ollama) {
        throw 'Không tìm thấy ollama.exe. Cài Ollama rồi tải model bge-m3:latest.'
    }
    Start-Process -FilePath $ollama -ArgumentList 'serve' -WindowStyle Hidden
    for ($attempt = 0; $attempt -lt 30 -and -not (Test-OllamaReady); $attempt++) {
        Start-Sleep -Seconds 1
    }
    if (-not (Test-OllamaReady)) {
        throw 'Ollama local không sẵn sàng ở 127.0.0.1:11434.'
    }
}

& $python $queryScript --question $Question --strategy $Strategy --top-k $TopK
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
