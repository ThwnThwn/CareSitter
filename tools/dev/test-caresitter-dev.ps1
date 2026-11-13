[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'caresitter-dev.ps1') -App caregiver

function Assert-Equal {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message`nExpected: $Expected`nActual: $Actual"
    }
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ("caresitter-dev-test-{0}" -f [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $temporaryRoot
try {
    $envPath = Join-Path $temporaryRoot '.env.local'
    [System.IO.File]::WriteAllText(
        $envPath,
        "BASE_URL=https://old.example/api/v1`r`nKEEP_VALUE=unchanged`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Update-EnvUrls -Path $envPath -PublicUrl 'https://new.example/'
    $updated = [System.IO.File]::ReadAllText($envPath)
    Assert-Equal $true ($updated.Contains("BASE_URL=https://new.example/api/v1`r`n")) `
        'BASE_URL không được cập nhật đúng.'
    Assert-Equal $true ($updated.Contains("HUB_BASE_URL=https://new.example`r`n")) `
        'HUB_BASE_URL không được thêm đúng.'
    Assert-Equal $true ($updated.Contains("KEEP_VALUE=unchanged`r`n")) `
        'Giá trị không liên quan đã bị thay đổi.'

    $publicDefaultsPath = Join-Path $temporaryRoot '.env'
    [System.IO.File]::WriteAllText(
        $publicDefaultsPath,
        "GOOGLE_WEB_CLIENT_ID=web-client.apps.googleusercontent.com`n" +
            "GOOGLE_IOS_CLIENT_ID=ios-client.apps.googleusercontent.com`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $googleSettings = Get-CustomerGoogleSignInSettings `
        -LocalEnvPath $envPath -PublicDefaultsPath $publicDefaultsPath
    Assert-Equal 'web-client.apps.googleusercontent.com' $googleSettings.WebClientId `
        'Không đọc GOOGLE_WEB_CLIENT_ID từ cấu hình public mặc định.'
    Assert-Equal 'ios-client.apps.googleusercontent.com' $googleSettings.IosClientId `
        'Không đọc GOOGLE_IOS_CLIENT_ID từ cấu hình public mặc định.'
    Assert-Equal 'com.googleusercontent.apps.ios-client' $googleSettings.ReversedIosClientId `
        'Không tạo đúng reversed iOS client ID.'

    Sync-CustomerGoogleSignInConfiguration `
        -LocalEnvPath $envPath `
        -PublicDefaultsPath $publicDefaultsPath `
        -XcconfigPath (Join-Path $temporaryRoot 'GoogleSignIn.local.xcconfig')
    $syncedEnv = [System.IO.File]::ReadAllText($envPath)
    Assert-Equal $true `
        ($syncedEnv.Contains('GOOGLE_WEB_CLIENT_ID=web-client.apps.googleusercontent.com')) `
        'Launcher không đồng bộ Web client ID public vào .env.local.'
    Assert-Equal $true `
        ($syncedEnv.Contains('GOOGLE_IOS_CLIENT_ID=ios-client.apps.googleusercontent.com')) `
        'Launcher không đồng bộ iOS client ID public vào .env.local.'
    $googleXcconfig = [System.IO.File]::ReadAllText(
        (Join-Path $temporaryRoot 'GoogleSignIn.local.xcconfig')
    )
    Assert-Equal "GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.ios-client`n" `
        $googleXcconfig `
        'Launcher không tạo đúng xcconfig callback Google iOS.'

    $safe = Protect-DevLogMessage `
        -Message 'Authorization=Bearer-value password=hunter2 token:abc123'
    Assert-Equal $false ($safe.Contains('hunter2')) 'Log còn chứa password.'
    Assert-Equal $false ($safe.Contains('abc123')) 'Log còn chứa token.'
    $both = (Get-SelectedAppNames -Selection 'both') -join ','
    Assert-Equal 'customer,caregiver' $both `
        'Thứ tự chạy both không đúng.'

    $fallbackExecutable = Join-Path $temporaryRoot 'fallback-xcross.exe'
    [System.IO.File]::WriteAllText($fallbackExecutable, 'fixture')
    $selectedExecutable = Select-FirstExistingFile -Paths @(
        (Join-Path $temporaryRoot 'missing-xcross.exe'),
        $fallbackExecutable
    )
    Assert-Equal $fallbackExecutable $selectedExecutable `
        'Không chọn xcross dự phòng khi file chính bị thiếu.'

    $configuration = Read-DevConfiguration
    Assert-Equal $true `
        ([string]$configuration.backend.project).EndsWith('CareSitter.AppHost.csproj') `
        'Launcher phải chạy AppHost để bật đồng thời API và Nutrition.'
    Assert-Equal 'backend/orchestration/CareSitter.AppHost' `
        ([string]$configuration.backend.workingDirectory) `
        'Launcher phải chạy từ thư mục AppHost để dùng đúng .NET 10 SDK.'
    Assert-Equal 'http://localhost:5035' ([string]$configuration.backend.nutritionUrl) `
        'Launcher thiếu health URL của Nutrition.'
    $stableXcrossPath = [System.IO.Path]::GetFullPath(
        [string]$configuration.xcross.fallbackPaths[0]
    )
    Assert-Equal $stableXcrossPath (Get-XcrossPath -Configuration $configuration) `
        'Phải ưu tiên bản xcross ổ D để launcher không phụ thuộc LocalAppData.'
    $stableXcrossRoot = Split-Path -Parent (Split-Path -Parent $stableXcrossPath)
    $macroServerPath = Join-Path $stableXcrossRoot 'lib\OpenAppleMacrosServer.exe'
    Assert-Equal $true (Test-Path -LiteralPath $macroServerPath -PathType Leaf) `
        'Bản xcross ổ D phải kèm OpenAppleMacrosServer dựng sẵn.'

    $toolSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'caresitter-dev.ps1') -Raw
    Assert-Equal $true `
        ($toolSource.Contains("`$env:XCROSS_CACHE_DIR = Join-Path `$env:USERPROFILE '.xcross-cache'")) `
        'Launcher phải dùng cache SwiftPM đã build FirebaseFirestore thành công.'
    Assert-Equal $false ($toolSource -match "NutritionGateway__Enabled\s*=\s*'false'") `
        'Launcher không được tắt Nutrition gateway.'
    Assert-Equal $true ($toolSource.Contains("NutritionDatabase__ManageLocalRuntimePassword = 'true'")) `
        'Launcher phải đồng bộ role Nutrition local trước khi mở service.'
    Assert-Equal $true ($toolSource.Contains("'ok', 'healthy', 'ready', 'up'")) `
        'Health checker phải chấp nhận trạng thái ready/up của Nutrition.'

    $xcrossFixture = Join-Path $temporaryRoot 'xcross-config-probe.cmd'
    $observedConfig = Join-Path $temporaryRoot 'observed-config.txt'
    $observedCache = Join-Path $temporaryRoot 'observed-cache.txt'
    $observedArguments = Join-Path $temporaryRoot 'observed-arguments.txt'
    [System.IO.File]::WriteAllText($xcrossFixture, @'
@echo off
set XCROSS_CONFIG > "%~dp0observed-config.txt" 2>nul
set XCROSS_CACHE_DIR > "%~dp0observed-cache.txt" 2>nul
echo %* > "%~dp0observed-arguments.txt"
if errorlevel 1 echo XCROSS_CONFIG missing> "%~dp0observed-config.txt"
exit /b 0
'@)
    $previousStateDirectory = $script:StateDirectory
    $previousConfig = $env:XCROSS_CONFIG
    $previousCache = $env:XCROSS_CACHE_DIR
    try {
        $script:StateDirectory = $temporaryRoot
        $xcrossConfigPath = Join-Path $temporaryRoot 'xcross-config.yaml'
        [System.IO.File]::WriteAllText($xcrossConfigPath, 'roots: {}')
        Remove-Item Env:XCROSS_CONFIG -ErrorAction SilentlyContinue
        $env:XCROSS_CACHE_DIR = Join-Path $temporaryRoot 'stale-cache'
        Start-XcrossApp -Configuration $configuration -AppName customer -XcrossPath $xcrossFixture
        Assert-Equal "XCROSS_CONFIG=$xcrossConfigPath" `
            (Get-Content -LiteralPath $observedConfig -Raw).Trim() `
            'Launcher phải truyền file cấu hình chung cho xcross khi CMD không có XCROSS_CONFIG.'
        Assert-Equal $true ([string]::IsNullOrEmpty($env:XCROSS_CONFIG)) `
            'Launcher phải khôi phục XCROSS_CONFIG của tiến trình gọi.'
        Assert-Equal "XCROSS_CACHE_DIR=$(Join-Path $env:USERPROFILE '.xcross-cache')" `
            (Get-Content -LiteralPath $observedCache -Raw).Trim() `
            'Launcher phải thay cache cũ bằng cache SwiftPM đã kiểm chứng.'
        Assert-Equal $true `
            ((Get-Content -LiteralPath $observedArguments -Raw).Contains('--dart-define=LAB3_DEMO_ENABLED=true')) `
            'Customer CMD phải bật mục Kiểm chứng Lab3 trong bản debug.'
        Assert-Equal $true `
            ((Get-Content -LiteralPath $observedArguments -Raw).Contains('--dart-entrypoint-args=-FIRDebugEnabled')) `
            'Customer CMD phải bật Firebase Analytics DebugView trên iPhone.'
        Assert-Equal (Join-Path $temporaryRoot 'stale-cache') $env:XCROSS_CACHE_DIR `
            'Launcher phải khôi phục XCROSS_CACHE_DIR sau phiên chạy.'

        $env:XCROSS_CONFIG = Join-Path $temporaryRoot 'custom-config.yaml'
        Start-XcrossApp -Configuration $configuration -AppName customer -XcrossPath $xcrossFixture
        Assert-Equal "XCROSS_CONFIG=$env:XCROSS_CONFIG" `
            (Get-Content -LiteralPath $observedConfig -Raw).Trim() `
            'Launcher phải tôn trọng XCROSS_CONFIG được chỉ định riêng.'
    }
    finally {
        $script:StateDirectory = $previousStateDirectory
        $env:XCROSS_CONFIG = $previousConfig
        $env:XCROSS_CACHE_DIR = $previousCache
    }

    $launchers = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cmd' -File)
    Assert-Equal 1 $launchers.Count 'Phải có đúng một launcher CMD.'
    Assert-Equal 'CareSitter.cmd' $launchers[0].Name 'Tên launcher không đúng.'
    $launcherText = Get-Content -LiteralPath $launchers[0].FullName -Raw
    foreach ($argument in @('-App customer', '-App caregiver', '-App both', '-Stop')) {
        Assert-Equal $true ($launcherText.Contains($argument)) `
            "Launcher thiếu lựa chọn $argument."
    }
    Assert-Equal $true ($launcherText -match '(?im)^pause\s*$') `
        'Launcher phải giữ cửa sổ lại để người dùng đọc lỗi.'

    Write-Host 'PASS: CareSitter dev tool tests.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
