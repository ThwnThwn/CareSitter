[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$RemoteRepository,
    [Parameter(Mandatory)][string]$Archive
)

$ErrorActionPreference = 'Stop'
if ($Target -notmatch '^(?:[a-zA-Z0-9._-]+@)?[a-zA-Z0-9._-]+$') {
    throw 'Target must be an SSH host or user@host without shell characters.'
}
if ($RemoteRepository -notmatch '^/[a-zA-Z0-9._/-]+$' -or
    $RemoteRepository.Contains('..') -or $RemoteRepository -eq '/') {
    throw 'RemoteRepository must be a new absolute Linux release directory.'
}
$RemoteRepository = $RemoteRepository.TrimEnd('/')
$Archive = (Resolve-Path -LiteralPath $Archive).Path
if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
    throw 'Source archive does not exist.'
}
$archiveHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()

& ssh $Target "set -eu; test ! -e '$RemoteRepository'; mkdir -p '$RemoteRepository'"
if ($LASTEXITCODE -ne 0) { throw 'Remote release path already exists or cannot be created.' }
& scp $Archive "${Target}:$RemoteRepository/source.tar.gz"
if ($LASTEXITCODE -ne 0) { throw 'Unable to upload source archive.' }

$remoteCommand = "set -eu; cd '$RemoteRepository'; printf '%s  %s\n' '$archiveHash' source.tar.gz | sha256sum -c - >/dev/null; tar -xzf source.tar.gz; sha256sum -c deploy/source-manifest.sha256 >/dev/null; rm source.tar.gz; test -f deploy/source-revision.txt"
& ssh $Target $remoteCommand
if ($LASTEXITCODE -ne 0) { throw 'Remote source verification failed. Inspect the new release path before using it.' }
Write-Output "Verified the local source package at $Target`:$RemoteRepository."
