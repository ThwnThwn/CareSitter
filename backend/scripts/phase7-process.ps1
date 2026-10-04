# Keep log pumps in .NET tasks, not Start-Process's PowerShell event callbacks.
# The process and log streams stay alive until both redirected pipes reach EOF.
function Start-Phase7LoggedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath
    )

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo.FileName = $FilePath
    $process.StartInfo.WorkingDirectory = $WorkingDirectory
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $process.StartInfo.ArgumentList.Add($argument)
    }

    $stdoutStream = $null
    $stderrStream = $null
    try {
        $stdoutStream = [System.IO.File]::Open($StdoutPath,
            [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $stderrStream = [System.IO.File]::Open($StderrPath,
            [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        if (-not $process.Start()) { throw 'Unable to start the baseline process.' }
        return [pscustomobject]@{
            Process = $process
            StdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
            StderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
            StdoutStream = $stdoutStream
            StderrStream = $stderrStream
            Stopped = $false
        }
    }
    catch {
        if ($null -ne $stdoutStream) { $stdoutStream.Dispose() }
        if ($null -ne $stderrStream) { $stderrStream.Dispose() }
        $process.Dispose()
        throw
    }
}

function Stop-Phase7LoggedProcess {
    [CmdletBinding()]
    param($Handle)

    if ($null -eq $Handle -or $Handle.Stopped) { return }
    $process = $Handle.Process
    if (-not $process.HasExited) {
        try {
            # Stop descendants as well, never just the dotnet run launcher.
            $process.Kill($true)
        }
        catch [System.InvalidOperationException] {
            if (-not $process.HasExited) { throw }
        }
    }
    if (-not $process.WaitForExit(10000)) {
        throw 'Baseline process did not stop within 10 seconds.'
    }

    $logTasks = [System.Threading.Tasks.Task]::WhenAll(
        [System.Threading.Tasks.Task[]]@($Handle.StdoutTask, $Handle.StderrTask))
    # Do not dispose streams while a pump is still writing. A timeout fails the
    # gate instead of claiming cleanup succeeded or hanging indefinitely.
    try {
        if (-not $logTasks.Wait(10000)) {
            throw 'Baseline process log pipes did not close within 10 seconds.'
        }
        $logTasks.GetAwaiter().GetResult()
    }
    finally {
        if ($logTasks.IsCompleted) {
            $Handle.StdoutStream.Dispose()
            $Handle.StderrStream.Dispose()
            $process.Dispose()
            $Handle.Stopped = $true
        }
    }
}
