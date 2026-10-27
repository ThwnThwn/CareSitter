<#
.SYNOPSIS
Validates a completed Nutrition M4 review batch and optionally writes a new ledger revision.

.DESCRIPTION
Runs the existing hash-, role-, and receipt-aware importer. By default it only creates a
dry-run plan. Pass -Apply to write a new ledger, and provide a new -LedgerOutput path.
The input ledger and review batch are never overwritten.

.EXAMPLE
.\nutrition-review-import.ps1 -TargetKind case -BatchPath backend/artifacts/nutrition-knowledge-local/evaluation/case-review-batch.json -PlanOutput backend/artifacts/nutrition-knowledge-local/evaluation/case-review-plan.v1.json

.EXAMPLE
.\nutrition-review-import.ps1 -TargetKind graph -BatchPath backend/artifacts/nutrition-knowledge-local/evaluation/graph-review-batch.json -PlanOutput backend/artifacts/nutrition-knowledge-local/evaluation/graph-review-plan.v1.json -LedgerOutput backend/artifacts/nutrition-knowledge-local/graphs/book-heading.review.v16.json -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('case', 'graph')]
    [string]$TargetKind,

    [Parameter(Mandatory)]
    [string]$BatchPath,

    [Parameter(Mandatory)]
    [string]$PlanOutput,

    [string]$TargetPath,
    [string]$CorpusFreezePath = 'backend/artifacts/nutrition-knowledge-local/evaluation/dinh-duong-lam-sang-2019.retrieval-corpus-freeze.v3.json',
    [string]$LedgerPath,
    [string]$ChunksPath = 'backend/artifacts/nutrition-knowledge-local/corpus/dinh-duong-lam-sang-2019.chunks.v3.jsonl',

    [switch]$Apply,
    [string]$LedgerOutput,
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$artifactRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'backend/artifacts/nutrition-knowledge-local'))
$toolRoot = Join-Path $repoRoot 'backend/services/nutrition/tools/nutrition_knowledge_manual'

if ($TargetKind -eq 'case') {
    if (-not $TargetPath) { $TargetPath = 'backend/artifacts/nutrition-knowledge-local/evaluation/pdf-review-draft.v9.json' }
    if (-not $LedgerPath) { $LedgerPath = 'backend/artifacts/nutrition-knowledge-local/evaluation/pdf-review-draft.ledger.v9.json' }
} else {
    if (-not $TargetPath) { $TargetPath = 'backend/artifacts/nutrition-knowledge-local/graphs/book-heading.candidate.v15.json' }
    if (-not $LedgerPath) { $LedgerPath = 'backend/artifacts/nutrition-knowledge-local/graphs/book-heading.review.v15.json' }
}

if ($Apply -and -not $LedgerOutput) {
    throw 'Khi dùng -Apply, cần chỉ định -LedgerOutput là đường dẫn ledger revision mới.'
}
if (-not $Apply -and $LedgerOutput) {
    throw 'Chỉ dùng -LedgerOutput cùng với -Apply; dry-run mặc định không ghi ledger.'
}

function Resolve-RepoRelativePath([string]$Path, [string]$Label) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }
    $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $fullPath)
    if ($relativePath -eq '..' -or $relativePath.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)") -or [System.IO.Path]::IsPathRooted($relativePath)) {
        throw "$Label phải nằm trong repository: $Path"
    }
    return $relativePath
}

function Resolve-ArtifactOutput([string]$Path, [string]$Label) {
    $relativePath = Resolve-RepoRelativePath $Path $Label
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    $relativeToArtifacts = [System.IO.Path]::GetRelativePath($artifactRoot, $fullPath)
    if ($relativeToArtifacts -eq '..' -or $relativeToArtifacts.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)") -or [System.IO.Path]::IsPathRooted($relativeToArtifacts)) {
        throw "$Label phải nằm trong backend/artifacts/nutrition-knowledge-local: $Path"
    }
    if (Test-Path -LiteralPath $fullPath) {
        throw "$Label đã tồn tại; chọn revision/path mới để giữ nguyên bằng chứng cũ: $Path"
    }
    return $relativePath
}

$batchRelative = Resolve-RepoRelativePath $BatchPath 'BatchPath'
$targetRelative = Resolve-RepoRelativePath $TargetPath 'TargetPath'
$freezeRelative = Resolve-RepoRelativePath $CorpusFreezePath 'CorpusFreezePath'
$ledgerRelative = Resolve-RepoRelativePath $LedgerPath 'LedgerPath'
$chunksRelative = Resolve-RepoRelativePath $ChunksPath 'ChunksPath'
$planRelative = Resolve-ArtifactOutput $PlanOutput 'PlanOutput'
$ledgerOutputRelative = $null
if ($Apply) { $ledgerOutputRelative = Resolve-ArtifactOutput $LedgerOutput 'LedgerOutput' }

foreach ($input in @(
    @{ Path = $batchRelative; Label = 'BatchPath' },
    @{ Path = $targetRelative; Label = 'TargetPath' },
    @{ Path = $freezeRelative; Label = 'CorpusFreezePath' },
    @{ Path = $ledgerRelative; Label = 'LedgerPath' },
    @{ Path = $chunksRelative; Label = 'ChunksPath' }
)) {
    $fullPath = Join-Path $repoRoot $input.Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "$($input.Label) không tồn tại: $fullPath"
    }
}

$pythonPathBefore = $env:PYTHONPATH
$env:PYTHONPATH = if ($pythonPathBefore) { "$($toolRoot)/src;$pythonPathBefore" } else { Join-Path $toolRoot 'src' }

Write-Host "Chạy dry-run cho $TargetKind..."
$planArgs = @(
    '--workspace', $repoRoot,
    'plan-retrieval-review-import',
    '--target-kind', $TargetKind,
    '--target', $targetRelative,
    '--corpus-freeze', $freezeRelative,
    '--ledger', $ledgerRelative,
    '--batch', $batchRelative,
    '--output', $planRelative
)
& $Python -m nutrition_knowledge_manual @planArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$planFullPath = Join-Path $repoRoot $planRelative
$plan = Get-Content -LiteralPath $planFullPath -Raw | ConvertFrom-Json
Write-Host "Reviewer: $($plan.reviewer_id) | Vai trò: $($plan.reviewer_role)"
foreach ($category in @('accepted', 'unchanged', 'missing', 'duplicate', 'stale_hash', 'conflict', 'wrong_role')) {
    $ids = @($plan.outcomes.$category)
    Write-Host ("{0}: {1}" -f $category, $ids.Count)
    if ($ids.Count -gt 0 -and $category -notin @('accepted', 'unchanged')) {
        foreach ($id in $ids) { Write-Host "  - $id" }
    }
}

if (-not $plan.can_apply) {
    Write-Host "Dry-run có lỗi chặn; không ghi ledger. Xem plan: $planFullPath" -ForegroundColor Red
    exit 2
}
Write-Host "Dry-run sạch. Plan: $planFullPath"

if (-not $Apply) {
    Write-Host 'Chỉ kiểm tra; ledger chưa được ghi. Chạy lại với -Apply và một -LedgerOutput revision mới để áp dụng.'
    exit 0
}

Write-Host "Áp dụng kết quả vào ledger revision mới: $ledgerOutputRelative"
$applyArgs = @(
    '--workspace', $repoRoot,
    'apply-retrieval-review-import',
    '--target-kind', $TargetKind,
    '--target', $targetRelative,
    '--corpus-freeze', $freezeRelative,
    '--ledger', $ledgerRelative,
    '--batch', $batchRelative,
    '--plan', $planRelative,
    '--output', $ledgerOutputRelative
)
& $Python -m nutrition_knowledge_manual @applyArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Đã ghi ledger revision mới; receipt nằm trong ledger. Input ledger và batch review được giữ nguyên.'
