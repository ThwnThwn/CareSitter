[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$nutritionRoot = Join-Path $PSScriptRoot '../services/nutrition'
$bundle = Get-Content -LiteralPath (Join-Path $nutritionRoot 'catalog/drafts/adult-baseline-variety-demo.bundle.json') -Raw | ConvertFrom-Json
$snapshot = Get-Content -LiteralPath (Join-Path $nutritionRoot 'catalog/sources/nin-food-composition-2026-10-24.json') -Raw | ConvertFrom-Json
$foods = @{}
foreach ($food in $snapshot.foods) { $foods[$food.conceptCode] = $food }
$issues = [Collections.Generic.List[string]]::new()
$checked = 0
foreach ($version in $bundle.recipes) {
    $recipe = $version.payload
    if ($recipe.sources -notcontains 'CARESITTER_VARIETY_ADAPTATION_V2' -and
        $recipe.sources -notcontains 'CARESITTER_HOME_MEALS_DEMO') { continue }
    $checked++
    foreach ($key in @('energy_kcal', 'protein_g', 'carbohydrate_g', 'fat_g', 'fiber_g', 'sodium_mg')) {
        [decimal]$total = 0
        $complete = $true
        foreach ($ingredient in $recipe.ingredients) {
            $food = $foods[$ingredient.code]
            if (!$food -or $food.perAmount -le 0 -or $food.perUnit -ne $ingredient.unit -or
                $food.basis -ne $ingredient.basis -or $null -eq $food.nutrients.$key.value) {
                $issues.Add("$($recipe.name): missing or incompatible input for $($ingredient.code)/$key")
                $complete = $false
                continue
            }
            $total += [decimal]$food.nutrients.$key.value * [decimal]$ingredient.amount / [decimal]$food.perAmount
        }
        if ($complete -and ($null -eq $recipe.nutrients.$key -or
            [Math]::Round($total, 2, [MidpointRounding]::AwayFromZero) -ne [decimal]$recipe.nutrients.$key)) {
            $issues.Add("$($recipe.name): nutrient total mismatch for $key")
        }
    }
}
if ($checked -eq 0) { throw 'No adapted recipes found; audit cannot pass on an empty set.' }
if ($issues.Count -gt 0) { throw ($issues -join [Environment]::NewLine) }
Write-Output "PASS: $checked adapted recipes x 6 nutrients match the pinned snapshot and ingredient units/basis."
Write-Output 'Scope: arithmetic only; excludes added seasoning and cooking losses; does not validate clinical suitability or source data accuracy.'
