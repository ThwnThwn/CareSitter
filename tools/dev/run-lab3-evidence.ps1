[CmdletBinding()]
param(
    [string]$OutputRoot,
    [switch]$SkipCustomer,
    [switch]$SkipAdmin,
    [switch]$SkipBackend,
    [switch]$NoOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = (Resolve-Path (Join-Path $scriptDirectory '..\..')).Path
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repositoryRoot 'artifacts\lab3-evidence'
}

$runDirectory = Join-Path $OutputRoot $runStamp
$logsDirectory = Join-Path $runDirectory 'logs'
$resultsDirectory = Join-Path $runDirectory 'test-results'
$null = New-Item -ItemType Directory -Force -Path $logsDirectory, $resultsDirectory

function Protect-EvidenceLine {
    param([AllowEmptyString()][string]$Line)

    if ($null -eq $Line) {
        return ''
    }

    $protected = $Line
    $patterns = @(
        '(?i)(authorization\s*[:=]\s*bearer\s+)[^\s,;]+',
        '(?i)(bearer\s+)[A-Za-z0-9._~+\-/=]+',
        '(?i)((?:password|secret|token|api[_-]?key|client[_-]?secret)\s*[:=]\s*)[^\s,;]+'
    )
    foreach ($pattern in $patterns) {
        $protected = [regex]::Replace($protected, $pattern, '${1}[REDACTED]')
    }
    return $protected
}

function Invoke-EvidenceCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogPath
    )

    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    Write-Host "Thu muc: $WorkingDirectory"
    Write-Host "Log: $LogPath"

    $previousLocation = Get-Location
    $exitCode = 1
    $writer = $null
    try {
        Set-Location -LiteralPath $WorkingDirectory
        $writer = [System.IO.StreamWriter]::new(
            $LogPath,
            $false,
            [System.Text.UTF8Encoding]::new($false)
        )
        & $Executable @Arguments 2>&1 | ForEach-Object {
            $safeLine = Protect-EvidenceLine -Line ([string]$_)
            $writer.WriteLine($safeLine)
            $writer.Flush()
            Write-Host $safeLine
        }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $safeError = Protect-EvidenceLine -Line $_.Exception.Message
        if ($null -ne $writer) {
            $writer.WriteLine($safeError)
            $writer.Flush()
        }
        else {
            $safeError | Set-Content -LiteralPath $LogPath -Encoding UTF8
        }
        Write-Host $safeError -ForegroundColor Red
        $exitCode = 1
    }
    finally {
        if ($null -ne $writer) {
            $writer.Dispose()
        }
        Set-Location -LiteralPath $previousLocation
    }

    return [pscustomobject]@{
        Name = $Name
        ExitCode = $exitCode
        LogPath = $LogPath
    }
}

function New-SuiteResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'WARN', 'NOT_RUN')][string]$Status,
        [Parameter(Mandatory)][string]$Detail,
        [string]$Evidence = ''
    )

    return [pscustomobject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
        Evidence = $Evidence
    }
}

function Get-RelativeEvidencePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }
    return $Path.Substring($runDirectory.Length).TrimStart('\', '/')
}

function Get-FlutterResult {
    param($CommandResult)

    $text = Get-Content -Raw -LiteralPath $CommandResult.LogPath
    $count = $null
    $skipped = 0
    $matches = [regex]::Matches($text, '(?m)^\s*\d+:\d+\s+\+(\d+)(?:\s+~(\d+))?')
    if ($matches.Count -gt 0) {
        $last = $matches[$matches.Count - 1]
        $count = [int]$last.Groups[1].Value
        if ($last.Groups[2].Success) {
            $skipped = [int]$last.Groups[2].Value
        }
    }

    if ($CommandResult.ExitCode -ne 0) {
        return New-SuiteResult -Name 'Customer Flutter' -Status FAIL `
            -Detail 'Flutter test thất bại. Xem log chi tiết.' `
            -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    if ($skipped -gt 0) {
        return New-SuiteResult -Name 'Customer Flutter' -Status WARN `
            -Detail "$count test đạt, $skipped test bị skip; skip không tính là PASS." `
            -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    $detail = if ($null -ne $count) { "$count test đạt, 0 fail, 0 skip." } else {
        'Lệnh test thành công; xem log để đối chiếu số lượng.'
    }
    return New-SuiteResult -Name 'Customer Flutter' -Status PASS -Detail $detail `
        -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
}

function Get-AdminResult {
    param($CommandResult)

    $text = Get-Content -Raw -LiteralPath $CommandResult.LogPath
    $passed = 0
    $skipped = 0
    $passedMatch = [regex]::Match($text, '(?m)^\s*Tests\s+(\d+)\s+passed')
    $skippedMatch = [regex]::Match($text, '(?m)^\s*Tests.*?\|\s*(\d+)\s+skipped')
    if ($passedMatch.Success) { $passed = [int]$passedMatch.Groups[1].Value }
    if ($skippedMatch.Success) { $skipped = [int]$skippedMatch.Groups[1].Value }

    if ($CommandResult.ExitCode -ne 0) {
        return New-SuiteResult -Name 'Admin Web' -Status FAIL `
            -Detail 'Vitest thất bại. Xem log chi tiết.' `
            -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    if ($skipped -gt 0) {
        return New-SuiteResult -Name 'Admin Web' -Status WARN `
            -Detail "$passed test đạt, $skipped test bị skip; skip không tính là PASS." `
            -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    $detail = if ($passed -gt 0) { "$passed test đạt, 0 fail, 0 skip." } else {
        'Lệnh test thành công; xem log để đối chiếu số lượng.'
    }
    return New-SuiteResult -Name 'Admin Web' -Status PASS -Detail $detail `
        -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
}

function Get-DotNetResult {
    param($CommandResult)

    $trxFiles = @(Get-ChildItem -LiteralPath $resultsDirectory -Filter '*.trx' -File -ErrorAction SilentlyContinue)
    $total = 0
    $passed = 0
    $failed = 0
    $skipped = 0
    foreach ($trxFile in $trxFiles) {
        [xml]$trx = Get-Content -Raw -LiteralPath $trxFile.FullName
        $counters = $trx.TestRun.ResultSummary.Counters
        if ($null -ne $counters) {
            $total += [int]$counters.total
            $passed += [int]$counters.passed
            $failed += [int]$counters.failed
            $skipped += [int]$counters.total - [int]$counters.passed - [int]$counters.failed
        }
    }

    $evidence = Get-RelativeEvidencePath $resultsDirectory
    if ($CommandResult.ExitCode -ne 0 -or $failed -gt 0) {
        $detail = "$passed/$total test đạt, $failed fail, $skipped skip."
        if ($CommandResult.ExitCode -ne 0 -and $failed -eq 0) {
            $detail += ' Lệnh dotnet test lỗi ngoài các test đã chạy; xem log build/test.'
        }
        return New-SuiteResult -Name 'Backend .NET' -Status FAIL `
            -Detail $detail -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    if ($skipped -gt 0) {
        return New-SuiteResult -Name 'Backend .NET' -Status WARN `
            -Detail "$passed/$total test đạt, 0 fail, $skipped skip; cần DB/cấu hình phù hợp để chạy phần bị skip." `
            -Evidence $evidence
    }
    if ($trxFiles.Count -eq 0) {
        return New-SuiteResult -Name 'Backend .NET' -Status WARN `
            -Detail 'Lệnh thành công nhưng không tìm thấy TRX để xác minh số lượng.' `
            -Evidence (Get-RelativeEvidencePath $CommandResult.LogPath)
    }
    return New-SuiteResult -Name 'Backend .NET' -Status PASS `
        -Detail "$passed/$total test đạt, 0 fail, 0 skip." -Evidence $evidence
}

function Get-DeviceAcceptanceResult {
    $acceptancePath = Join-Path $repositoryRoot `
        'plan\kiem-thu\lab3-2026-11-07\device-acceptance.json'
    if (-not (Test-Path -LiteralPath $acceptancePath)) {
        return New-SuiteResult -Name 'iPhone / ARTEMIS' -Status NOT_RUN `
            -Detail 'Không tìm thấy hồ sơ device-acceptance.json.'
    }

    $acceptance = Get-Content -Raw -LiteralPath $acceptancePath | ConvertFrom-Json
    $executions = @($acceptance.executions)
    $passed = @($executions | Where-Object status -eq 'PASS').Count
    $failed = @($executions | Where-Object status -eq 'FAIL').Count
    $notRun = @($executions | Where-Object status -eq 'NOT_RUN').Count
    $other = $executions.Count - $passed - $failed - $notRun
    $status = if ($failed -gt 0) { 'FAIL' } elseif ($notRun -gt 0 -or $other -gt 0) {
        'NOT_RUN'
    } else { 'PASS' }
    $detail = "$passed/$($executions.Count) lượt PASS, $failed FAIL, $notRun NOT_RUN"
    if ($other -gt 0) { $detail += ", $other trạng thái khác" }
    $detail += '. Đây là kiểm thử thao tác thật, runner không tự đánh dấu PASS.'
    return New-SuiteResult -Name 'iPhone / ARTEMIS' -Status $status -Detail $detail `
        -Evidence 'plan\kiem-thu\lab3-2026-11-07\device-acceptance.json'
}

$suiteResults = [System.Collections.Generic.List[object]]::new()

if ($SkipCustomer) {
    $suiteResults.Add((New-SuiteResult -Name 'Customer Flutter' -Status NOT_RUN `
        -Detail 'Đã bỏ qua theo tham số -SkipCustomer.'))
}
elseif (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $suiteResults.Add((New-SuiteResult -Name 'Customer Flutter' -Status NOT_RUN `
        -Detail 'Không tìm thấy lệnh flutter trong PATH.'))
}
else {
    $customerDirectory = Join-Path $repositoryRoot 'frontend\customer-app'
    $customerLog = Join-Path $logsDirectory 'customer-flutter.log'
    $customerCommand = Invoke-EvidenceCommand -Name 'Customer Flutter' `
        -WorkingDirectory $customerDirectory -Executable 'flutter' `
        -Arguments @('test', '--no-pub', '--reporter', 'expanded') -LogPath $customerLog
    $suiteResults.Add((Get-FlutterResult $customerCommand))
}

if ($SkipAdmin) {
    $suiteResults.Add((New-SuiteResult -Name 'Admin Web' -Status NOT_RUN `
        -Detail 'Đã bỏ qua theo tham số -SkipAdmin.'))
}
elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    $suiteResults.Add((New-SuiteResult -Name 'Admin Web' -Status NOT_RUN `
        -Detail 'Không tìm thấy lệnh npm trong PATH.'))
}
else {
    $adminDirectory = Join-Path $repositoryRoot 'frontend\admin-web'
    $adminLog = Join-Path $logsDirectory 'admin-vitest.log'
    $adminCommand = Invoke-EvidenceCommand -Name 'Admin Web' `
        -WorkingDirectory $adminDirectory -Executable 'npm' `
        -Arguments @('test') -LogPath $adminLog
    $suiteResults.Add((Get-AdminResult $adminCommand))
}

if ($SkipBackend) {
    $suiteResults.Add((New-SuiteResult -Name 'Backend .NET' -Status NOT_RUN `
        -Detail 'Đã bỏ qua theo tham số -SkipBackend.'))
}
elseif (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    $suiteResults.Add((New-SuiteResult -Name 'Backend .NET' -Status NOT_RUN `
        -Detail 'Không tìm thấy lệnh dotnet trong PATH.'))
}
else {
    $backendLog = Join-Path $logsDirectory 'backend-dotnet.log'
    $backendCommand = Invoke-EvidenceCommand -Name 'Backend .NET' `
        -WorkingDirectory $repositoryRoot -Executable 'dotnet' `
        -Arguments @(
            'test', 'backend\CareSitter.sln', '--nologo', '--configuration', 'Release',
            '--logger', 'trx;LogFilePrefix=backend',
            '--results-directory', $resultsDirectory
        ) -LogPath $backendLog
    $suiteResults.Add((Get-DotNetResult $backendCommand))
}

$suiteResults.Add((Get-DeviceAcceptanceResult))

$finishedAt = Get-Date
$summaryPath = Join-Path $runDirectory 'summary.txt'
$summaryLines = @(
    'CARESITTER - LAB 3 TEST EVIDENCE',
    "Thoi gian: $($finishedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    "Thu muc: $runDirectory",
    '',
    ('{0,-22} {1,-9} {2}' -f 'PHAM VI', 'TRANG THAI', 'KET QUA'),
    ('-' * 100)
)
foreach ($result in $suiteResults) {
    $summaryLines += ('{0,-22} {1,-9} {2}' -f $result.Name, $result.Status, $result.Detail)
}
$summaryLines += @(
    '',
    'Quy uoc: test bi skip hoac chua chay khong duoc tinh la PASS.',
    'Khong dua token, credential hoac secret vao anh/log nop bai.'
)
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$statusColors = @{
    PASS = '#087f5b'
    FAIL = '#c92a2a'
    WARN = '#e67700'
    NOT_RUN = '#6c757d'
}
$rows = foreach ($result in $suiteResults) {
    $name = [System.Net.WebUtility]::HtmlEncode($result.Name)
    $status = [System.Net.WebUtility]::HtmlEncode($result.Status)
    $detail = [System.Net.WebUtility]::HtmlEncode($result.Detail)
    $evidence = [System.Net.WebUtility]::HtmlEncode($result.Evidence)
    $color = $statusColors[$result.Status]
    "<tr><td><strong>$name</strong></td><td><span class='badge' style='background:$color'>$status</span></td><td>$detail</td><td><code>$evidence</code></td></tr>"
}
$reportPath = Join-Path $runDirectory 'report.html'
$generatedAt = [System.Net.WebUtility]::HtmlEncode(
    $finishedAt.ToString('yyyy-MM-dd HH:mm:ss zzz')
)
$html = @"
<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CareSitter - Lab 3 Test Evidence</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f4f7f6;color:#1f2d27;margin:0;padding:36px}
main{max-width:1200px;margin:auto;background:white;border-top:10px solid #087f5b;padding:34px;box-shadow:0 8px 28px #0001}
h1{margin:0 0 8px}.meta{color:#66756f;margin-bottom:28px}table{width:100%;border-collapse:collapse}
th,td{text-align:left;padding:15px 12px;border-bottom:1px solid #dfe7e3;vertical-align:top}
th{color:#087f5b;font-size:13px}.badge{display:inline-block;color:white;border-radius:999px;padding:5px 10px;font-weight:700;font-size:12px}
code{font-size:12px;word-break:break-word}.note{margin-top:26px;padding:16px;background:#fff4e6;border-left:5px solid #e67700}
</style>
</head>
<body><main>
<h1>CareSitter · Bằng chứng kiểm thử Lab 3</h1>
<div class="meta">Tạo lúc $generatedAt · Kết quả lấy trực tiếp từ runner local</div>
<table><thead><tr><th>Phạm vi</th><th>Trạng thái</th><th>Kết quả</th><th>Bằng chứng</th></tr></thead>
<tbody>$($rows -join "`n")</tbody></table>
<div class="note"><strong>Lưu ý:</strong> test bị skip và kiểm thử thiết bị chưa chạy không được tính là PASS. Không chụp hoặc nộp token/credential/secret.</div>
</main></body></html>
"@
$html | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "`n=== TONG HOP ===" -ForegroundColor Cyan
Get-Content -LiteralPath $summaryPath | ForEach-Object { Write-Host $_ }
Write-Host "`nBao cao de chup anh: $reportPath" -ForegroundColor Green

if (-not $NoOpen) {
    Start-Process -FilePath $reportPath
}

$hasFailure = @($suiteResults | Where-Object Status -eq 'FAIL').Count -gt 0
if ($hasFailure) {
    exit 1
}
exit 0
