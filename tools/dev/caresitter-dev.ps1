[CmdletBinding()]
param(
    [ValidateSet('caregiver', 'customer', 'both')]
    [string]$App = 'caregiver',
    [switch]$DryRun,
    [switch]$SkipBackend,
    [switch]$Stop,
    [ValidateRange(1, 60)]
    [int]$NetworkRetries = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ToolRoot = $PSScriptRoot
$script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:ConfigPath = Join-Path $PSScriptRoot 'apps.json'
$script:LogDirectory = Join-Path $PSScriptRoot 'logs'
$script:StateDirectory = Join-Path $PSScriptRoot 'state'
$script:LogPath = $null

function Protect-DevLogMessage {
    param([Parameter(Mandatory)][string]$Message)

    $sanitized = $Message -replace '(?i)Bearer\s+[^\s]+', 'Bearer <redacted>'
    $sensitiveAssignmentPattern =
        '(?i)(password|secret|token|api[_-]?key|authorization)(\s*[:=]\s*)[^\s;]+'
    $sanitized = $sanitized -replace $sensitiveAssignmentPattern, '$1$2<redacted>'
    return $sanitized
}

function Write-DevLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $safeMessage = Protect-DevLogMessage -Message $Message
    $colors = @{ INFO = 'Cyan'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red' }
    Write-Host "[$Level] $safeMessage" -ForegroundColor $colors[$Level]
    if ($null -ne $script:LogPath) {
        $line = '{0:o} [{1}] {2}' -f [DateTimeOffset]::Now, $Level, $safeMessage
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding utf8
    }
}

function Resolve-RepoPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $resolved = [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot $RelativePath))
    $rootWithSeparator = $script:RepoRoot.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Đường dẫn cấu hình vượt khỏi repository: $RelativePath"
    }
    return $resolved
}

function Read-DevConfiguration {
    if (-not (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)) {
        throw "Thiếu cấu hình công cụ: $script:ConfigPath"
    }

    try {
        return Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding utf8 |
            ConvertFrom-Json -Depth 10
    }
    catch {
        throw "Không đọc được apps.json. Hãy kiểm tra JSON: $($_.Exception.Message)"
    }
}

function Get-SelectedAppNames {
    param([Parameter(Mandatory)][string]$Selection)

    if ($Selection -eq 'both') {
        return @('customer', 'caregiver')
    }
    return @($Selection)
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Select-FirstExistingFile {
    param([Parameter(Mandatory)][string[]]$Paths)

    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
        $candidate = [System.IO.Path]::GetFullPath($expandedPath)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    return $null
}

function Test-HealthContent {
    param(
        [Parameter(Mandatory)][string]$Url,
        [hashtable]$Headers = @{}
    )

    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $Headers -TimeoutSec 5
        if ($null -eq $response) {
            return $false
        }
        if ($response -is [string]) {
            return $response.Trim().ToLowerInvariant() -in @('ok', 'healthy', 'ready', 'up')
        }
        $statusProperty = $response.PSObject.Properties['status']
        if ($null -ne $statusProperty) {
            return ([string]$statusProperty.Value).Trim().ToLowerInvariant() -in @('ok', 'healthy', 'ready', 'up')
        }
        return $false
    }
    catch {
        return $false
    }
}

function Wait-HealthContent {
    param(
        [Parameter(Mandatory)][string]$Url,
        [hashtable]$Headers = @{},
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][int]$Retries
    )

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        if (Test-HealthContent -Url $Url -Headers $Headers) {
            Write-DevLog "$DisplayName đã sẵn sàng." 'OK'
            return
        }
        if ($attempt -lt $Retries) {
            Start-Sleep -Seconds ([Math]::Min(5, 1 + $attempt))
        }
    }
    throw "$DisplayName chưa sẵn sàng sau $Retries lần kiểm tra: $Url"
}

function Get-XcrossPath {
    param([Parameter(Mandatory)]$Configuration)

    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'Windows không trả về thư mục LocalApplicationData.'
    }
    $localAppDataPath = [System.IO.Path]::GetFullPath(
        (Join-Path $localAppData ([string]$Configuration.xcross.relativeLocalAppDataPath))
    )
    $fallbackPaths = @()
    $fallbackProperty = $Configuration.xcross.PSObject.Properties['fallbackPaths']
    if ($null -ne $fallbackProperty) {
        $fallbackPaths = @($fallbackProperty.Value | ForEach-Object { [string]$_ })
    }
    $candidatePaths = $fallbackPaths + @($localAppDataPath)
    $selectedPath = Select-FirstExistingFile -Paths $candidatePaths
    if ($null -eq $selectedPath) {
        throw "Không tìm thấy bản xcross CareSitter. Đã kiểm tra: $($candidatePaths -join ', ')"
    }
    if (
        $fallbackPaths.Count -gt 0 -and
        $selectedPath.Equals($localAppDataPath, [StringComparison]::OrdinalIgnoreCase)
    ) {
        Write-DevLog "Không thấy xcross ổ D; đang dùng bản LocalAppData: $selectedPath" 'WARN'
    }
    return $selectedPath
}

function Test-AppleServices {
    $appleService = Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue
    if ($null -eq $appleService) {
        Write-DevLog 'Không thấy Apple Mobile Device Service. Hãy cài iTunes/Apple Mobile Device Support nếu xcross không nhận iPhone.' 'WARN'
    }
    elseif ($appleService.Status -ne 'Running') {
        Write-DevLog 'Apple Mobile Device Service chưa chạy; Windows có thể tự bật khi cắm iPhone.' 'WARN'
    }

    $bonjour = Get-Service -Name 'Bonjour Service' -ErrorAction SilentlyContinue
    if ($null -eq $bonjour) {
        Write-DevLog 'Không thấy Bonjour Service. USB vẫn có thể chạy, nhưng phát hiện thiết bị qua mạng sẽ không hoạt động.' 'WARN'
    }
}

function Test-DevPreflight {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string[]]$AppNames
    )

    Write-DevLog 'Đang kiểm tra môi trường...'
    $xcrossPath = Get-XcrossPath -Configuration $Configuration
    if (-not (Test-Path -LiteralPath $xcrossPath -PathType Leaf)) {
        throw "Không tìm thấy bản xcross CareSitter tại: $xcrossPath"
    }

    foreach ($appName in $AppNames) {
        $appConfig = $Configuration.apps.$appName
        if ($null -eq $appConfig) {
            throw "apps.json không có cấu hình app '$appName'."
        }
        $appDirectory = Resolve-RepoPath -RelativePath ([string]$appConfig.dir)
        $envPath = Join-Path $appDirectory ([string]$appConfig.envFile)
        if (-not (Test-Path -LiteralPath $appDirectory -PathType Container)) {
            throw "Không tìm thấy thư mục $($appConfig.displayName): $appDirectory"
        }
        if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
            throw "Thiếu $($appConfig.displayName)/$($appConfig.envFile). Hãy tạo từ file example và điền cấu hình local."
        }
        if ([string]::IsNullOrWhiteSpace([string]$appConfig.bundleId)) {
            throw "Thiếu bundleId của '$appName' trong apps.json."
        }
        if ($appName -eq 'customer') {
            $null = Get-CustomerGoogleSignInSettings `
                -LocalEnvPath $envPath `
                -PublicDefaultsPath (Join-Path $appDirectory '.env')
        }
    }

    if (-not $SkipBackend) {
        foreach ($command in @('docker', 'dotnet')) {
            if (-not (Test-CommandAvailable -Name $command)) {
                throw "Không tìm thấy lệnh '$command' trong PATH."
            }
        }
        $composePath = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.composeFile)
        $projectPath = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.project)
        if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
            throw "Không tìm thấy docker compose: $composePath"
        }
        if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
            throw "Không tìm thấy ApiHost project: $projectPath"
        }
    }

    Test-AppleServices
    Write-DevLog 'Preflight đạt.' 'OK'
    return $xcrossPath
}

function Stop-ManagedDotnetProcess {
    param(
        [Parameter(Mandatory)][string]$StateFileName,
        [Parameter(Mandatory)][string]$DisplayName,
        [switch]$Quiet
    )

    $statePath = Join-Path $script:StateDirectory $StateFileName
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        if (-not $Quiet) {
            Write-DevLog "Không có $DisplayName nào do công cụ ghi nhận để dừng." 'WARN'
        }
        return $false
    }

    try {
        $processState = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 |
            ConvertFrom-Json
        $savedPid = [int]$processState.processId
        $savedStartTicks = [long]$processState.startTimeUtcTicks
        $process = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        $isOwnedProcess =
            $null -ne $process -and
            $process.ProcessName -eq 'dotnet' -and
            $process.StartTime.ToUniversalTime().Ticks -eq $savedStartTicks
        if ($isOwnedProcess) {
            Stop-Process -Id $savedPid -Force -ErrorAction Stop
            Write-DevLog "Đã dừng $DisplayName do công cụ khởi động." 'OK'
            return $true
        }
        if ($null -ne $process) {
            Write-DevLog "Không dừng PID đã lưu vì tiến trình hiện tại không khớp $DisplayName do tool tạo." 'WARN'
        }
        return $false
    }
    catch {
        Write-DevLog "State $DisplayName không hợp lệ; không dừng bất kỳ process nào." 'WARN'
        return $false
    }
    finally {
        Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    }
}

function Start-BackendStack {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][int]$Retries
    )

    $composePath = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.composeFile)
    $apiBaseUrl = ([string]$Configuration.backend.apiUrl).TrimEnd('/')
    $localHealthUrl = "$apiBaseUrl/health/live"
    $nutritionBaseUrl = ([string]$Configuration.backend.nutritionUrl).TrimEnd('/')
    $nutritionHealthUrl = "$nutritionBaseUrl/health/ready"

    $null = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop chưa chạy hoặc Docker engine chưa sẵn sàng.'
    }

    Write-DevLog 'Đang bảo đảm PostgreSQL, Redis, Kafka và ngrok đã chạy...'
    $composeOutput = & docker compose -f $composePath up -d db redis kafka ngrok 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Không bật được Docker stack. Hãy chạy docker compose thủ công để xem chi tiết."
    }

    $apiIsReady = Test-HealthContent -Url $localHealthUrl
    $nutritionIsReady = Test-HealthContent -Url $nutritionHealthUrl
    if ($apiIsReady -and $nutritionIsReady) {
        Write-DevLog 'API và Nutrition local đã chạy sẵn; không mở tiến trình thứ hai.' 'OK'
        return
    }

    if ($apiIsReady -and -not $nutritionIsReady) {
        $null = Stop-ManagedDotnetProcess -StateFileName 'api-process.json' `
            -DisplayName 'ApiHost cũ' -Quiet
        Start-Sleep -Seconds 1
        if (Test-HealthContent -Url $localHealthUrl) {
            throw 'Port API 5033 đang do tiến trình khác sử dụng. Hãy dừng ApiHost cũ rồi chạy lại để AppHost bật cả Nutrition.'
        }
    }
    if (-not $apiIsReady -and $nutritionIsReady) {
        throw 'Port Nutrition 5035 đang do tiến trình khác sử dụng. Hãy dừng Nutrition cũ rồi chạy lại.'
    }

    $null = Stop-ManagedDotnetProcess -StateFileName 'apphost-process.json' `
        -DisplayName 'CareSitter AppHost cũ' -Quiet

    $projectPath = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.project)
    $workingDirectory = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.workingDirectory)
    if (-not (Test-Path -LiteralPath $script:StateDirectory)) {
        $null = New-Item -ItemType Directory -Path $script:StateDirectory
    }

    Write-DevLog 'Đang bật CareSitter API và Nutrition ở chế độ local...'
    $previousRuntimePasswordManagement = $env:NutritionDatabase__ManageLocalRuntimePassword
    $previousBookingChat = $env:BookingChat__Enabled
    try {
        $env:NutritionDatabase__ManageLocalRuntimePassword = 'true'
        $env:BookingChat__Enabled = 'true'
        $startProcessArguments = @{
            FilePath = 'dotnet'
            ArgumentList = @(
                'run',
                '--project',
                ('"{0}"' -f $projectPath)
            )
            WorkingDirectory = $workingDirectory
            WindowStyle = 'Hidden'
            PassThru = $true
        }
        $appHostProcess = Start-Process @startProcessArguments
    }
    finally {
        $env:NutritionDatabase__ManageLocalRuntimePassword = $previousRuntimePasswordManagement
        $env:BookingChat__Enabled = $previousBookingChat
    }

    $processState = [ordered]@{
        processId = $appHostProcess.Id
        startTimeUtcTicks = $appHostProcess.StartTime.ToUniversalTime().Ticks
    }
    $processState | ConvertTo-Json | Set-Content `
        -LiteralPath (Join-Path $script:StateDirectory 'apphost-process.json') `
        -Encoding utf8
    try {
        Wait-HealthContent -Url $nutritionHealthUrl -DisplayName 'Nutrition local' -Retries $Retries
        Wait-HealthContent -Url $localHealthUrl -DisplayName 'API local' -Retries $Retries
    }
    catch {
        if (-not $appHostProcess.HasExited) {
            Stop-Process -Id $appHostProcess.Id -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Get-NgrokPublicUrl {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][int]$Retries
    )

    $inspectUrl = ([string]$Configuration.backend.ngrokInspectUrl).TrimEnd('/')
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri "$inspectUrl/api/tunnels" -TimeoutSec 5
            $publicUrl = $response.tunnels |
                Where-Object { $_.public_url -like 'https://*' } |
                Select-Object -First 1 -ExpandProperty public_url
            if (-not [string]::IsNullOrWhiteSpace([string]$publicUrl)) {
                $uri = [Uri]$publicUrl
                if ($uri.Scheme -eq 'https' -and -not [string]::IsNullOrWhiteSpace($uri.Host)) {
                    return $uri.AbsoluteUri.TrimEnd('/')
                }
            }
        }
        catch {
            # Retry below. Raw provider errors are intentionally not logged.
        }
        if ($attempt -lt $Retries) {
            Start-Sleep -Seconds ([Math]::Min(5, 1 + $attempt))
        }
    }
    throw "Không lấy được HTTPS URL từ ngrok inspect tại $inspectUrl."
}

function Update-EnvUrls {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$PublicUrl
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Không tìm thấy env file: $Path"
    }
    $uri = [Uri]$PublicUrl
    if ($uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host)) {
        throw 'URL ngrok phải là HTTPS URL hợp lệ.'
    }

    $text = [System.IO.File]::ReadAllText($Path)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $values = [ordered]@{
        BASE_URL = "$($uri.AbsoluteUri.TrimEnd('/'))/api/v1"
        HUB_BASE_URL = $uri.AbsoluteUri.TrimEnd('/')
    }
    foreach ($key in $values.Keys) {
        $pattern = "(?m)^$([regex]::Escape($key))=[^`r`n]*"
        $replacement = "$key=$($values[$key])"
        if ([regex]::IsMatch($text, $pattern)) {
            $text = [regex]::Replace($text, $pattern, $replacement)
        }
        else {
            if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) {
                $text += $newline
            }
            $text += $replacement + $newline
        }
    }

    $temporaryPath = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            $text,
            [System.Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Get-DotEnvValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $pattern = "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$"
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -notmatch $pattern) {
            continue
        }
        return $Matches[1].Trim().Trim('"').Trim("'")
    }
    return $null
}

function Set-DotEnvValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Không tìm thấy env file: $Path"
    }
    $text = [System.IO.File]::ReadAllText($Path)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    foreach ($key in $Values.Keys) {
        $pattern = "(?m)^$([regex]::Escape([string]$key))=[^`r`n]*"
        $replacement = "$key=$($Values[$key])"
        if ([regex]::IsMatch($text, $pattern)) {
            $text = [regex]::Replace($text, $pattern, $replacement)
        }
        else {
            if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) {
                $text += $newline
            }
            $text += $replacement + $newline
        }
    }

    $temporaryPath = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            $text,
            [System.Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Get-CustomerGoogleSignInSettings {
    param(
        [Parameter(Mandatory)][string]$LocalEnvPath,
        [Parameter(Mandatory)][string]$PublicDefaultsPath
    )

    $webClientId = Get-DotEnvValue -Path $LocalEnvPath -Key 'GOOGLE_WEB_CLIENT_ID'
    if ([string]::IsNullOrWhiteSpace($webClientId)) {
        $webClientId = Get-DotEnvValue `
            -Path $PublicDefaultsPath -Key 'GOOGLE_WEB_CLIENT_ID'
    }
    $iosClientId = Get-DotEnvValue -Path $LocalEnvPath -Key 'GOOGLE_IOS_CLIENT_ID'
    if ([string]::IsNullOrWhiteSpace($iosClientId)) {
        $iosClientId = Get-DotEnvValue `
            -Path $PublicDefaultsPath -Key 'GOOGLE_IOS_CLIENT_ID'
    }

    $clientIdPattern = '^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$'
    if ($webClientId -notmatch $clientIdPattern) {
        throw 'Customer thiếu GOOGLE_WEB_CLIENT_ID hợp lệ trong .env.local hoặc .env.'
    }
    if ($iosClientId -notmatch $clientIdPattern) {
        throw 'Customer thiếu GOOGLE_IOS_CLIENT_ID hợp lệ. Hãy tạo OAuth client loại iOS cho bundle ID vn.caresitter.customer trong Google Cloud rồi điền client ID vào frontend/customer-app/.env.local.'
    }

    $iosClientPrefix = $iosClientId.Substring(
        0,
        $iosClientId.Length - '.apps.googleusercontent.com'.Length
    )
    return [pscustomobject]@{
        WebClientId = $webClientId
        IosClientId = $iosClientId
        ReversedIosClientId = "com.googleusercontent.apps.$iosClientPrefix"
    }
}

function Sync-CustomerGoogleSignInConfiguration {
    param(
        [Parameter(Mandatory)][string]$LocalEnvPath,
        [Parameter(Mandatory)][string]$PublicDefaultsPath,
        [Parameter(Mandatory)][string]$XcconfigPath
    )

    $settings = Get-CustomerGoogleSignInSettings `
        -LocalEnvPath $LocalEnvPath -PublicDefaultsPath $PublicDefaultsPath
    Set-DotEnvValues -Path $LocalEnvPath -Values ([ordered]@{
        GOOGLE_WEB_CLIENT_ID = $settings.WebClientId
        GOOGLE_IOS_CLIENT_ID = $settings.IosClientId
    })
    [System.IO.File]::WriteAllText(
        $XcconfigPath,
        "GOOGLE_REVERSED_CLIENT_ID=$($settings.ReversedIosClientId)`n",
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Sync-AppEnvironmentUrls {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string[]]$AppNames,
        [Parameter(Mandatory)][string]$PublicUrl
    )

    foreach ($appName in $AppNames) {
        $appConfig = $Configuration.apps.$appName
        $appDirectory = Resolve-RepoPath -RelativePath ([string]$appConfig.dir)
        $envPath = Join-Path $appDirectory ([string]$appConfig.envFile)
        Update-EnvUrls -Path $envPath -PublicUrl $PublicUrl
        Write-DevLog "Đã đồng bộ URL cho $($appConfig.displayName)." 'OK'
    }
}

function Sync-CustomerGoogleSignInIfSelected {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string[]]$AppNames
    )

    if ('customer' -notin $AppNames) {
        return
    }
    $customerConfig = $Configuration.apps.customer
    $customerDirectory = Resolve-RepoPath -RelativePath ([string]$customerConfig.dir)
    Sync-CustomerGoogleSignInConfiguration `
        -LocalEnvPath (Join-Path $customerDirectory ([string]$customerConfig.envFile)) `
        -PublicDefaultsPath (Join-Path $customerDirectory '.env') `
        -XcconfigPath (Join-Path $customerDirectory 'ios\Flutter\GoogleSignIn.local.xcconfig')
    Write-DevLog 'Đã đồng bộ cấu hình Google Sign-In cho Customer.' 'OK'
}

function Start-XcrossApp {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string]$AppName,
        [Parameter(Mandatory)][string]$XcrossPath
    )

    $appConfig = $Configuration.apps.$AppName
    $appDirectory = Resolve-RepoPath -RelativePath ([string]$appConfig.dir)
    $xcrossConfigPath = Join-Path $script:StateDirectory 'xcross-config.yaml'
    $previousConfig = $env:XCROSS_CONFIG
    $previousCache = $env:XCROSS_CACHE_DIR

    Write-DevLog "Đang chạy $($appConfig.displayName). Giữ iPhone mở khóa; bấm q để thoát."
    Push-Location $appDirectory
    try {
        # Dùng chung cấu hình SDK giữa CMD và Codex, vốn có thể thấy AppData khác nhau.
        if ([string]::IsNullOrWhiteSpace($previousConfig) -and
            (Test-Path -LiteralPath $xcrossConfigPath -PathType Leaf)) {
            $env:XCROSS_CONFIG = $xcrossConfigPath
        }
        # Dùng cache đã xác nhận build FirebaseFirestore trên iPhone.
        $env:XCROSS_CACHE_DIR = Join-Path $env:USERPROFILE '.xcross-cache'
        $runArguments = @('flutter', 'run', '--debug', '--usb', '--dart-define-from-file=.env.local')
        if ($AppName -eq 'customer') {
            $runArguments += '--dart-define=LAB3_DEMO_ENABLED=true'
            $runArguments += '--dart-entrypoint-args=-FIRDebugEnabled'
            Write-DevLog 'Đã bật mục Kiểm chứng Lab3 cho Customer debug.'
            Write-DevLog 'Đã bật Firebase Analytics DebugView trên iPhone.'
        }
        & $XcrossPath @runArguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        $env:XCROSS_CONFIG = $previousConfig
        if ([string]::IsNullOrEmpty($previousCache)) {
            Remove-Item Env:XCROSS_CACHE_DIR -ErrorAction SilentlyContinue
        }
        else {
            $env:XCROSS_CACHE_DIR = $previousCache
        }
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "$($appConfig.displayName) không chạy được. xcross thoát với mã $exitCode. Xem lỗi chi tiết phía trên."
    }
    Write-DevLog "Đã kết thúc phiên $($appConfig.displayName)." 'OK'
}

function Stop-CareSitterDev {
    param([Parameter(Mandatory)]$Configuration)

    $stoppedAppHost = Stop-ManagedDotnetProcess `
        -StateFileName 'apphost-process.json' -DisplayName 'CareSitter AppHost' -Quiet
    $stoppedLegacyApi = Stop-ManagedDotnetProcess `
        -StateFileName 'api-process.json' -DisplayName 'ApiHost cũ' -Quiet
    if (-not $stoppedAppHost -and -not $stoppedLegacyApi) {
        Write-DevLog 'Không có backend nào do công cụ ghi nhận để dừng.' 'WARN'
    }

    if (Test-CommandAvailable -Name 'docker') {
        $composePath = Resolve-RepoPath -RelativePath ([string]$Configuration.backend.composeFile)
        $null = & docker compose -f $composePath stop ngrok 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DevLog 'Đã dừng ngrok; DB/Redis/Kafka được giữ nguyên.' 'OK'
        }
        else {
            Write-DevLog 'Không dừng được ngrok. Hãy kiểm tra Docker Desktop.' 'WARN'
        }
    }
}

function Show-DryRunPlan {
    param(
        [Parameter(Mandatory)]$Configuration,
        [Parameter(Mandatory)][string[]]$AppNames,
        [Parameter(Mandatory)][string]$XcrossPath
    )

    Write-DevLog 'Dry-run: không bật process, không sửa env và không chạy app.' 'OK'
    Write-DevLog "xcross: $XcrossPath"
    if (-not $SkipBackend) {
        Write-DevLog 'Kế hoạch: bật db/redis/kafka/ngrok, rồi mở AppHost cho API và Nutrition nếu health local chưa đạt.'
    }
    foreach ($appName in $AppNames) {
        $appConfig = $Configuration.apps.$appName
        Write-DevLog "Kế hoạch: đồng bộ BASE_URL/HUB_BASE_URL rồi chạy $($appConfig.displayName) qua USB."
    }
    if ($App -eq 'both') {
        Write-DevLog 'Customer chạy trước; sau khi bấm q, Caregiver tự chạy tiếp.'
    }
}

function Invoke-CareSitterDev {
    $configuration = Read-DevConfiguration

    if ($Stop) {
        if ($DryRun) {
            Write-DevLog 'Dry-run: sẽ chỉ dừng AppHost/backend do công cụ quản lý và container ngrok; DB/Redis/Kafka được giữ nguyên.' 'OK'
            return
        }
        if (-not $DryRun) {
            if (-not (Test-Path -LiteralPath $script:LogDirectory)) {
                $null = New-Item -ItemType Directory -Path $script:LogDirectory
            }
            $script:LogPath = Join-Path $script:LogDirectory `
                ("stop-{0:yyyyMMdd-HHmmss}.log" -f [DateTime]::Now)
        }
        Stop-CareSitterDev -Configuration $configuration
        return
    }

    $appNames = Get-SelectedAppNames -Selection $App
    if (-not $DryRun) {
        if (-not (Test-Path -LiteralPath $script:LogDirectory)) {
            $null = New-Item -ItemType Directory -Path $script:LogDirectory
        }
        $script:LogPath = Join-Path $script:LogDirectory `
            ("run-{0:yyyyMMdd-HHmmss}.log" -f [DateTime]::Now)
    }
    $xcrossPath = Test-DevPreflight -Configuration $configuration -AppNames $appNames
    if ($DryRun) {
        Show-DryRunPlan -Configuration $configuration -AppNames $appNames -XcrossPath $xcrossPath
        return
    }

    if (-not $SkipBackend) {
        Start-BackendStack -Configuration $configuration -Retries $NetworkRetries
    }
    $publicUrl = Get-NgrokPublicUrl -Configuration $configuration -Retries $NetworkRetries
    $publicHealth = "$($publicUrl.TrimEnd('/'))/health/live"
    Wait-HealthContent -Url $publicHealth `
        -Headers @{ 'ngrok-skip-browser-warning' = '1' } `
        -DisplayName 'API qua ngrok' -Retries $NetworkRetries
    Sync-AppEnvironmentUrls -Configuration $configuration `
        -AppNames $appNames -PublicUrl $publicUrl
    Sync-CustomerGoogleSignInIfSelected `
        -Configuration $configuration -AppNames $appNames

    foreach ($appName in $appNames) {
        Start-XcrossApp -Configuration $configuration `
            -AppName $appName -XcrossPath $xcrossPath
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-CareSitterDev
    }
    catch {
        Write-DevLog $_.Exception.Message 'ERROR'
        Write-Host 'Gợi ý: xem lỗi phía trên hoặc chạy lại với -DryRun để kiểm tra launcher.' -ForegroundColor Yellow
        exit 1
    }
}
