param(
    [string]$FlutterCommand = 'flutter'
)

$ErrorActionPreference = 'Stop'
$appDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$checkExitCode = 1

# Dùng cùng kiểm tra AST với CI: ranh giới tầng, file UI <=300 dòng,
# build <=80 dòng. Không duy trì danh sách ngoại lệ cũ trong script riêng.
Push-Location -LiteralPath $appDirectory
try {
    & $FlutterCommand test --no-pub --reporter expanded test/architecture/frontend_boundaries_test.dart
    $checkExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

exit $checkExitCode
