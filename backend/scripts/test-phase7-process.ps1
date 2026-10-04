[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'phase7-process.ps1')

$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ("caresitter-phase7-process-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$fixture = Join-Path $PSScriptRoot 'tests/phase7-process-fixture.ps1'
$pwshPath = (Get-Command pwsh).Source
$handle = $null
try {
    $message = 'argument with spaces and "quotes"'
    $stdout = Join-Path $testDirectory 'exit.stdout.log'
    $stderr = Join-Path $testDirectory 'exit.stderr.log'
    $handle = Start-Phase7LoggedProcess -FilePath $pwshPath `
        -Arguments @('-NoProfile', '-File', $fixture, '-Mode', 'Exit', '-Message', $message) `
        -WorkingDirectory $testDirectory -StdoutPath $stdout -StderrPath $stderr
    if (-not $handle.Process.WaitForExit(15000)) { throw 'Exit fixture timed out.' }
    if ($handle.Process.ExitCode -ne 7) { throw 'The native exit code was lost.' }
    Stop-Phase7LoggedProcess -Handle $handle
    if ((Get-Content -Raw -LiteralPath $stdout).Trim() -ne "stdout:$message" -or
        (Get-Content -Raw -LiteralPath $stderr).Trim() -ne "stderr:$message") {
        throw 'Argument quoting or log draining failed.'
    }
    Stop-Phase7LoggedProcess -Handle $handle # Cleanup is idempotent.
    Write-Host 'PASS native exit, argument boundaries, stdout/stderr drain and repeated cleanup'

    for ($iteration = 1; $iteration -le 5; $iteration++) {
        $stdout = Join-Path $testDirectory "running-$iteration.stdout.log"
        $stderr = Join-Path $testDirectory "running-$iteration.stderr.log"
        $handle = Start-Phase7LoggedProcess -FilePath $pwshPath `
            -Arguments @('-NoProfile', '-File', $fixture, '-Mode', 'Running', '-Message', 'active logging') `
            -WorkingDirectory $testDirectory -StdoutPath $stdout -StderrPath $stderr
        $ready = $false
        for ($attempt = 1; $attempt -le 100; $attempt++) {
            if ($handle.Process.HasExited) { throw 'Logging fixture exited unexpectedly.' }
            if ((Get-Item -LiteralPath $stdout).Length -gt 0 -and (Get-Item -LiteralPath $stderr).Length -gt 0) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 50
        }
        if (-not $ready) { throw 'Logging fixture did not write to both pipes.' }
        Stop-Phase7LoggedProcess -Handle $handle
        if (-not $handle.Stopped -or -not $handle.StdoutTask.IsCompleted -or -not $handle.StderrTask.IsCompleted) {
            throw 'Cleanup returned before log pumps completed.'
        }
        if ((Get-Content -Raw -LiteralPath $stdout) -notmatch 'stdout:heartbeat' -or
            (Get-Content -Raw -LiteralPath $stderr) -notmatch 'stderr:heartbeat') {
            throw 'Active process logs were lost.'
        }
    }
    Write-Host 'PASS stop during active logging, five consecutive processes, no closed-writer callback'

    $stdout = Join-Path $testDirectory 'fault.stdout.log'
    $stderr = Join-Path $testDirectory 'fault.stderr.log'
    $handle = Start-Phase7LoggedProcess -FilePath $pwshPath `
        -Arguments @('-NoProfile', '-File', $fixture, '-Mode', 'Exit', '-Message', 'fault cleanup') `
        -WorkingDirectory $testDirectory -StdoutPath $stdout -StderrPath $stderr
    if (-not $handle.Process.WaitForExit(15000) -or
        -not $handle.StdoutTask.Wait(15000) -or -not $handle.StderrTask.Wait(15000)) {
        throw 'Fault-cleanup fixture timed out.'
    }
    $handle.StdoutTask = [Threading.Tasks.Task]::FromException([IO.IOException]::new('injected log failure'))
    $failed = $false
    try { Stop-Phase7LoggedProcess -Handle $handle }
    catch { $failed = $true }
    if (-not $failed -or -not $handle.Stopped) {
        throw 'Log failures must fail the gate while disposing completed pumps.'
    }
    Write-Host 'PASS log-pump failure is reported and resources are released'

    $stdout = Join-Path $testDirectory 'missing.stdout.log'
    $stderr = Join-Path $testDirectory 'missing.stderr.log'
    $failed = $false
    try {
        $null = Start-Phase7LoggedProcess -FilePath (Join-Path $testDirectory 'missing-program') `
            -Arguments @('unused') -WorkingDirectory $testDirectory -StdoutPath $stdout -StderrPath $stderr
    }
    catch { $failed = $true }
    if (-not $failed) { throw 'Invalid executable did not fail.' }
    foreach ($logPath in @($stdout, $stderr)) {
        $exclusiveStream = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $exclusiveStream.Dispose()
    }
    Write-Host 'PASS failed startup releases log files'
}
finally {
    try { Stop-Phase7LoggedProcess -Handle $handle }
    finally {
        $resolved = (Resolve-Path -LiteralPath $testDirectory).Path
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        $item = Get-Item -LiteralPath $resolved
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $item.Name -notmatch '^caresitter-phase7-process-tests-[a-f0-9]{32}$' -or
            ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing to remove an unexpected process-test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
