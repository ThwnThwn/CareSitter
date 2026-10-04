param([ValidateSet('Exit', 'Running')][string]$Mode, [string]$Message)

[Console]::Out.WriteLine("stdout:$Message")
[Console]::Error.WriteLine("stderr:$Message")
if ($Mode -eq 'Exit') { exit 7 }

while ($true) {
    [Console]::Out.WriteLine('stdout:heartbeat')
    [Console]::Error.WriteLine('stderr:heartbeat')
    Start-Sleep -Milliseconds 5
}
