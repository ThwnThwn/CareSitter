param(
    [string]$Python312 = 'py',
    [string[]]$PythonArguments = @('-3.12')
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $moduleRoot 'src'
$workspaceRoot = (Resolve-Path (Join-Path $moduleRoot '..\..\..\..\..')).Path
$artifactRoot = Join-Path $workspaceRoot 'backend\artifacts\nutrition-knowledge-local'
$venvRoot = Join-Path $artifactRoot 'venv'
$cacheRoot = Join-Path $artifactRoot 'pip-cache'
$modelRoot = Join-Path $artifactRoot 'ollama-models'
$tempRoot = Join-Path $artifactRoot 'tmp'

New-Item -ItemType Directory -Force -Path $artifactRoot, $cacheRoot, $modelRoot, $tempRoot | Out-Null
$env:PIP_CACHE_DIR = $cacheRoot
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$env:OLLAMA_MODELS = $modelRoot
$env:OLLAMA_NO_CLOUD = '1'
$env:OLLAMA_HOST = '127.0.0.1:11434'

& $Python312 @PythonArguments -m venv $venvRoot
$venvPython = Join-Path $venvRoot 'Scripts\python.exe'
$sitePackages = & $venvPython -c "import sysconfig; print(sysconfig.get_paths()['purelib'])"
$sourceRoot | Set-Content -LiteralPath (Join-Path $sitePackages 'caresitter_nutrition_g0.pth') -Encoding ascii
& $venvPython -m nutrition_knowledge_g0 validate
& $venvPython -m nutrition_knowledge_g0 preflight --output (Join-Path $artifactRoot 'preflight.json')
