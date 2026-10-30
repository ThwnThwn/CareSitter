[CmdletBinding()]
param(
    [switch]$IncludeClientSource
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifactRoot = Join-Path $repository 'backend/artifacts'
$outputRoot = Join-Path $repository 'deploy/artifacts'
$suffix = [Guid]::NewGuid().ToString('N')
$staging = Join-Path $artifactRoot "source-package-$suffix"
$packageName = if ($IncludeClientSource) { 'caresitter-source' } else { 'caresitter-server-source' }
$archive = Join-Path $outputRoot "$packageName-$suffix.tar.gz"
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-DeploySource([string]$relative) {
    $relative = $relative.Replace('\', '/')
    if ($relative -notmatch '^(backend/|deploy/|frontend/admin-web/|frontend/customer-app/|frontend/caregiver-app/|frontend/landing-page/|global\.json$|vercel\.json$)') {
        return $false
    }
    if ($relative -in @('deploy/source-manifest.sha256', 'deploy/source-revision.txt')) {
        return $false
    }
    if ($relative -match '(^|/)\.\.(\/|$)|(^|/)(secrets|runtime|artifacts|node_modules|build|dist|bin|obj|\.next|\.dart_tool|\.hallmark)(/|$)') {
        return $false
    }
    if ($relative -match '(?i)\.(md|pem|pfx|p12|key|keystore|jks)$' -or
        $relative -match '(^|/)(AGENTS|CLAUDE)\.md$') {
        return $false
    }
    if ($relative -match '(?i)(^|/)[^/]*\.env(?:\.[^/]*)?$' -and
        $relative -notmatch '(?i)\.example$') {
        return $false
    }
    if ($relative -match '[\r\n\0]' -or $relative.StartsWith('/')) {
        throw 'Git returned an unsafe source path.'
    }
    return $true
}

try {
    New-Item -ItemType Directory -Path $staging, $outputRoot -Force | Out-Null
    $sourceRoots = @('backend', 'deploy', 'frontend/admin-web', 'global.json')
    if ($IncludeClientSource) {
        $sourceRoots += @(
            'frontend/customer-app',
            'frontend/caregiver-app',
            'frontend/landing-page',
            'vercel.json'
        )
    }
    $candidates = @(& git -c core.quotepath=false ls-files --cached --others --exclude-standard -- `
        $sourceRoots)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to list the local source tree.' }
    $files = @($candidates | Sort-Object -Unique | Where-Object { Assert-DeploySource $_ })
    if ($files.Count -eq 0) { throw 'No deployable source files were selected.' }
    $hashLines = [Collections.Generic.List[string]]::new()
    foreach ($relative in $files) {
        $source = Join-Path $repository $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        if (([IO.File]::GetAttributes($source) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to package a symlink: $relative"
        }
        $target = Join-Path $staging $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        if ($relative -match '\.(sh|sql)$') {
            $content = [IO.File]::ReadAllText($source).Replace("`r`n", "`n")
            [IO.File]::WriteAllText($target, $content, $utf8)
        }
        else {
            Copy-Item -LiteralPath $source -Destination $target
        }
        $digest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $hashLines.Add("$digest  $($relative.Replace('\','/'))")
    }
    $manifest = Join-Path $staging 'deploy/source-manifest.sha256'
    [IO.File]::WriteAllText($manifest, ([string]::Join("`n", $hashLines) + "`n"), $utf8)
    $head = (& git rev-parse HEAD).Trim()
    $dirty = @(& git status --porcelain --untracked-files=all).Count
    $revision = "HEAD=$head`nLOCAL_CHANGES=$dirty`nFILES=$($hashLines.Count)`nCREATED_UTC=$([DateTime]::UtcNow.ToString('o'))`n"
    [IO.File]::WriteAllText((Join-Path $staging 'deploy/source-revision.txt'), $revision, $utf8)
    & tar -czf $archive -C $staging .
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create the deployment source archive.' }
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Output "Created $archive"
    Write-Output "SHA256 $archiveHash"
    Write-Output "Packaged $($hashLines.Count) source files from HEAD $head with $dirty local changes."
}
finally {
    if (Test-Path -LiteralPath $staging) {
        $resolvedStaging = [IO.Path]::GetFullPath($staging)
        $resolvedRoot = [IO.Path]::GetFullPath($artifactRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) +
            [IO.Path]::DirectorySeparatorChar
        if (-not $resolvedStaging.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a directory outside backend/artifacts.'
        }
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
