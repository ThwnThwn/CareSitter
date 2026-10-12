# Script kiem tra do dai file va quy tac khong dung _buildXxx()
# Danh sach file ngoai le tam (cac file cu chua refactor theo plan)
$legacyLengthExceptions = @(
    'features\schedule\presentation\screens\schedule_screen.dart',
    'features\home\presentation\screens\home_screen.dart',
    'features\shifts\presentation\screens\shift_detail_screen.dart',
    'features\shifts\presentation\controllers\shift_list_controller.dart',
    'features\auth\presentation\screens\phone_input_screen.dart',
    'features\auth\presentation\screens\password_recovery_screen.dart',
    'features\auth\presentation\screens\recovery_email_screen.dart',
    'app\router\app_router.dart'
)

$legacyBuildExceptions = @(
    'features\auth\presentation\screens\otp_verify_screen.dart',
    'features\earnings\presentation\screens\earnings_screen.dart',
    'features\home\presentation\screens\home_screen.dart',
    'features\schedule\presentation\screens\schedule_screen.dart',
    'features\settings\presentation\screens\document_status_screen.dart',
    'features\settings\presentation\screens\settings_screen.dart',
    'features\settings\presentation\screens\support_screen.dart',
    'features\shifts\presentation\screens\shift_detail_screen.dart',
    'features\shifts\presentation\screens\shift_list_screen.dart',
    'features\shifts\presentation\screens\shift_summary_screen.dart'
)

$hasError = $false
$libDir = (Resolve-Path "$PSScriptRoot\..\lib").Path + "\"

Write-Host "=== 1. Kiem tra file vuot 300 dong ===" -ForegroundColor Cyan
$bad = Get-ChildItem lib -Recurse -Filter *.dart |
  Where-Object { $_.Name -notmatch '\.(g|freezed)\.dart$' } |
  ForEach-Object {
    $relative = $_.FullName.Replace($libDir, "")
    [pscustomobject]@{ Lines = (Get-Content $_.FullName).Count; File = $relative; FullPath = $_.FullName }
  } |
  Where-Object { $_.Lines -gt 300 }

$newViolations = $bad | Where-Object { $legacyLengthExceptions -notcontains $_.File }

if ($newViolations) {
  Write-Host "Phat hien file vuot nguong 300 dong:" -ForegroundColor Red
  $newViolations | Sort-Object Lines -Descending | Format-Table Lines, File -AutoSize
  $hasError = $true
} else {
  Write-Host "Tat ca file moi va file da refactor deu <= 300 dong!" -ForegroundColor Green
}

Write-Host "`n=== 2. Kiem tra method Widget _buildXxx() ===" -ForegroundColor Cyan
$buildHits = Get-ChildItem lib -Recurse -Filter *.dart |
  Where-Object { $_.Name -notmatch '\.(g|freezed)\.dart$' } |
  Select-String -Pattern 'Widget\s+_build\w*\s*\('

$unexceptedBuild = $buildHits | Where-Object {
  $relative = $_.Path.Replace($libDir, "")
  $legacyBuildExceptions -notcontains $relative
}

if ($unexceptedBuild) {
  Write-Host "Phat hien method Widget _buildXxx() ngoai danh sach ngoai le:" -ForegroundColor Red
  $unexceptedBuild | ForEach-Object { "$($_.Path):$($_.LineNumber)  $($_.Line.Trim())" }
  $hasError = $true
} else {
  Write-Host "Khong co method Widget _buildXxx() nao trong cac file da refactor va file moi!" -ForegroundColor Green
}

if ($hasError) {
  exit 1
} else {
  Write-Host "`nKiem tra thanh cong!" -ForegroundColor Green
  exit 0
}
