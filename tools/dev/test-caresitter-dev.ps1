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
        ($toolSource.Contains('Remove-Item Env:XCROSS_CACHE_DIR -ErrorAction SilentlyContinue')) `
        'Launcher phải xóa XCROSS_CACHE_DIR cũ được Explorer giữ lại trước khi chạy xcross.'
    Assert-Equal $false ($toolSource -match '\$env:XCROSS_CACHE_DIR\s*=') `
        'Launcher không được gán XCROSS_CACHE_DIR vì sẽ che Darwin SDK lúc flutter run.'

    $expectedLaunchers = [ordered]@{
        'run-customer-iphone.cmd' = 'customer'
        'run-caregiver-iphone.cmd' = 'caregiver'
        'run-both-iphone.cmd' = 'both'
    }
    foreach ($launcherName in $expectedLaunchers.Keys) {
        $launcherPath = Join-Path $PSScriptRoot $launcherName
        Assert-Equal $true (Test-Path -LiteralPath $launcherPath -PathType Leaf) `
            "Thiếu launcher một cú bấm: $launcherName"
        $launcherText = Get-Content -LiteralPath $launcherPath -Raw
        Assert-Equal $true ($launcherText -match '(?im)^pwsh\.exe\b') `
            "$launcherName phải gọi PowerShell 7 để đọc đúng UTF-8."
        Assert-Equal $true ($launcherText -match '(?im)^pause\s*$') `
            "$launcherName phải giữ cửa sổ lại để người dùng đọc lỗi."
        $appArgument = "-App $($expectedLaunchers[$launcherName])"
        Assert-Equal $true ($launcherText.Contains($appArgument)) `
            "$launcherName chọn sai app."
    }

    Write-Host 'PASS: CareSitter dev tool tests.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
