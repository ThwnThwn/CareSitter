param(
    [string]$Image = 'caresitter-render:nutrition',
    [string]$NutritionConnectionFile
)
$ErrorActionPreference = 'Stop'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$network = "render-test-$suffix"
$database = "render-db-$suffix"
$redis = "render-redis-$suffix"
$application = "render-app-$suffix"
$backend = Split-Path $PSScriptRoot -Parent

function Invoke-Docker([string[]]$DockerArguments) {
    $result = & docker @DockerArguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker failed: $($result -join [Environment]::NewLine)" }
    return $result
}

try {
    Invoke-Docker @('network', 'create', $network) | Out-Null
    Invoke-Docker @('run', '-d', '--name', $database, '--network', $network,
        '-e', 'POSTGRES_HOST_AUTH_METHOD=trust',
        '--mount', "type=bind,source=$backend/init-db,target=/sql,readonly",
        'postgis/postgis:16-3.4') | Out-Null
    $databaseReady = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        & docker exec $database pg_isready -h 127.0.0.1 -U postgres *> $null
        if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $databaseReady) { throw 'Disposable PostgreSQL did not finish initialization.' }
    Invoke-Docker @('exec', $database, 'psql', '-X', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1',
        '-c', 'CREATE DATABASE caresitter') | Out-Null
    Invoke-Docker @('exec', $database, 'psql', '-X', '-U', 'postgres', '-d', 'caresitter',
        '-v', 'ON_ERROR_STOP=1', '-f', '/sql/00-init.sql') | Out-Null
    Invoke-Docker @('exec', $database, 'psql', '-X', '-U', 'postgres',
        '-c', 'CREATE DATABASE nutrition') | Out-Null
    foreach ($migration in Get-ChildItem "$backend/init-db/nutrition-service/*.sql" | Sort-Object Name) {
        Invoke-Docker @('exec', $database, 'psql', '-X', '-U', 'postgres', '-d', 'nutrition',
            '-v', 'ON_ERROR_STOP=1', '-v', 'app_password=container-test-only',
            '-f', "/sql/nutrition-service/$($migration.Name)") | Out-Null
    }
    Invoke-Docker @('run', '-d', '--name', $redis, '--network', $network, 'redis:7-alpine') | Out-Null
    $configuration = @{
        PORT = '10000'; RENDER_NUTRITION_ENABLED = 'true'
        ConnectionStrings__CareSitter = "Host=$database;Database=caresitter;Username=postgres"
        ConnectionStrings__Nutrition = "Host=$database;Database=nutrition;Username=nutrition_app;Password=container-test-only"
        Redis__ConnectionString = "${redis}:6379"
        HANGFIRE_USE_POSTGRES = 'true'; KAFKA_ENABLED = 'false'
        Jwt__SecretKey = 'render-container-test-only-jwt-key-32-characters'
        Jwt__Issuer = 'CareSitter.Test'; Jwt__Audience = 'CareSitter.Test'
        Jwt__ExpiryMinutes = '60'; Jwt__RefreshTokenExpiryDays = '7'
        Encryption__EncryptionKey = 'render-test-encryption-key-32-chars'
        Public__ApiBaseUrl = 'https://api.example.test'
        Cors__AllowedOrigins__0 = 'https://customer.example.test'
        Proxy__KnownProxies__0 = '127.0.0.1'
        Smtp__Host = 'smtp.gmail.com'; Smtp__Port = '587'
        Smtp__UserName = 'test@example.test'; Smtp__Password = 'container-test-only'
        Smtp__FromName = 'CareSitter.Test'; Cloudinary__ApiSecret = 'container-test-only'
        Payments__VNPay__TmnCode = 'TESTONLY'; Payments__VNPay__HashSecret = 'container-test-only'
        Payments__VNPay__PaymentUrl = 'https://payments.example.test/pay'
        Payments__VNPay__QueryUrl = 'https://payments.example.test/query'
        Payments__VNPay__ReturnUrl = 'https://api.example.test/api/v1/payments/vnpay/return'
        Payments__VNPay__IpnUrl = 'https://api.example.test/api/v1/payments/vnpay/ipn'
        Payments__VNPay__CustomerWebUrl = 'https://customer.example.test'
    }
    $runArguments = @('run', '-d', '--name', $application, '--network', $network,
        '--memory=512m', '--cpus=0.5', '-p', '127.0.0.1::10000')
    if ($NutritionConnectionFile) {
        $configuration.ConnectionStrings__Nutrition = [IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $NutritionConnectionFile)).Trim()
    }
    foreach ($setting in $configuration.GetEnumerator()) { $runArguments += @('-e', "$($setting.Key)=$($setting.Value)") }
    Invoke-Docker ($runArguments + $Image) | Out-Null
    $healthy = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        & docker exec $application bash /app/render/healthcheck.sh *> $null
        if ($LASTEXITCODE -eq 0) { $healthy = $true; break }
        if ((& docker inspect --format '{{.State.Running}}' $application) -ne 'true') { break }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) {
        $logs = & docker logs --tail 70 $application 2>&1
        throw "Container did not become ready: $($logs -join [Environment]::NewLine)"
    }
    Write-Output 'PASS: Production API and Nutrition ready through verified HTTP/2 TLS within 512 MB.'
    Invoke-Docker @('exec', $application, 'bash', '-c', 'mkdir /tmp/caresitter-render.stale-test; echo stale > /tmp/caresitter-render.stale-test/ca.pem; bash /app/render/healthcheck.sh') | Out-Null
    Write-Output 'PASS: Stale certificate directories from an interrupted run do not break readiness.'
    $grpcProbe = 'set -eu; read -r ca < /tmp/caresitter-render-ca.path; curl --http2 --cacert "$ca" -sS -D /tmp/grpc-headers -o /dev/null -X POST -H "Content-Type: application/grpc" https://localhost:8444/caresitter.nutrition.v1.NutritionRpc/GetCapabilities; grep -qi "grpc-status: 16" /tmp/grpc-headers'
    Invoke-Docker @('exec', $application, 'bash', '-c', $grpcProbe) | Out-Null
    Write-Output 'PASS: gRPC rejects requests without internal service credentials.'
    $ports = @(Invoke-Docker @('port', $application))
    if ($ports.Count -ne 1 -or $ports[0] -notmatch '^10000/tcp -> 127\.0\.0\.1:') { throw 'Unexpected public port mapping.' }
    Write-Output 'PASS: Only the public API port is published.'
    $processes = Invoke-Docker @('top', $application, '-eo', 'pid,args')
    $nutritionLine = $processes | Where-Object { $_ -match 'dotnet CareSitter.Nutrition.dll' }
    if (@($nutritionLine).Count -ne 1) { throw 'Expected one Nutrition process.' }
    # Docker top uses host PIDs; kill the matching process inside its own PID namespace.
    Invoke-Docker @('exec', $application, 'bash', '-c', 'for p in /proc/[0-9]*/cmdline; do if [[ $(tr "\0" " " < "$p") == "dotnet CareSitter.Nutrition.dll " ]]; then kill -TERM "$(basename "$(dirname "$p")")"; break; fi; done') | Out-Null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if ((& docker inspect --format '{{.State.Running}}' $application) -eq 'false') { break }
        Start-Sleep -Seconds 1
    }
    $exitCode = Invoke-Docker @('inspect', '--format', '{{.State.ExitCode}}', $application)
    if ($exitCode -eq '0' -or (& docker inspect --format '{{.State.Running}}' $application) -ne 'false') {
        throw 'Container survived a stopped Nutrition process or returned success.'
    }
    Write-Output 'PASS: Stopping Nutrition shuts down the whole container with a failure status.'
}
finally {
    & docker rm -f $application $database $redis *> $null
    & docker network rm $network *> $null
}
