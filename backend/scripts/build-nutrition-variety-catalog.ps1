[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$catalog = Join-Path $root 'services/nutrition/catalog'
$bundle = Get-Content "$catalog/drafts/adult-baseline-book-demo.bundle.json" -Raw | ConvertFrom-Json -AsHashtable
$snapshotPath = "$catalog/sources/nin-food-composition-2026-10-24.json"
$snapshot = Get-Content $snapshotPath -Raw | ConvertFrom-Json -AsHashtable
$foods = @{}
foreach ($food in $snapshot.foods) { $foods[$food.conceptCode] = $food }
# These are CareSitter-authored combinations, not recipes quoted from the book.
# Gram weights follow the food snapshot's raw/cooked basis; no ml-to-g assumption.
$specs = @(
    @('Cháo bò hành lá', 'breakfast', 'RICE_WHITE_RAW:50,BEEF_LEAN_RAW:50,SCALLION_FRESH:5', @(), @()),
    @('Cháo gà nấm hương', 'breakfast', 'RICE_WHITE_RAW:50,CHICKEN_RAW:60,SHIITAKE_DRY:3,SCALLION_FRESH:5', @(), @()),
    @('Cháo cá rô phi gừng', 'breakfast', 'RICE_WHITE_RAW:50,TILAPIA_RAW:70,GINGER_FRESH:3,SCALLION_FRESH:5', @('FISH'), @()),
    @('Cháo trứng cà chua', 'breakfast', 'RICE_WHITE_RAW:50,CHICKEN_EGG_RAW:50,TOMATO_FRESH:80,SCALLION_FRESH:5', @('EGG'), @('vegetarian')),
    @('Cháo thịt lợn bí xanh', 'breakfast', 'RICE_WHITE_RAW:50,PORK_LEAN_RAW:55,WINTER_MELON_FRESH:100,SCALLION_FRESH:5', @(), @()),
    @('Cháo bò cà chua', 'breakfast', 'RICE_WHITE_RAW:50,BEEF_LEAN_RAW:55,TOMATO_FRESH:80,SCALLION_FRESH:5', @(), @()),
    @('Cháo gà rau ngót', 'breakfast', 'RICE_WHITE_RAW:50,CHICKEN_RAW:60,SAUROPUS_FRESH:80', @(), @()),
    @('Cháo cá trắm hành gừng', 'breakfast', 'RICE_WHITE_RAW:50,GRASS_CARP_RAW:70,GINGER_FRESH:3,SCALLION_FRESH:5', @('FISH'), @()),
    @('Miến gà nấm hương', 'breakfast', 'GLASS_NOODLE_DRY:50,CHICKEN_RAW:60,SHIITAKE_DRY:3,SCALLION_FRESH:5', @(), @()),
    @('Miến bò cải thìa', 'breakfast', 'GLASS_NOODLE_DRY:50,BEEF_LEAN_RAW:55,BOK_CHOY_FRESH:100', @(), @()),
    @('Miến trứng cà chua', 'breakfast', 'GLASS_NOODLE_DRY:50,CHICKEN_EGG_RAW:50,TOMATO_FRESH:80', @('EGG'), @('vegetarian')),
    @('Miến đậu phụ nấm hương', 'breakfast', 'GLASS_NOODLE_DRY:50,TOFU_BOILED:80,SHIITAKE_DRY:3,BOK_CHOY_FRESH:80', @('SOY'), @('vegetarian')),
    @('Cháo đậu phụ rau ngót', 'breakfast', 'RICE_WHITE_RAW:50,TOFU_BOILED:90,SAUROPUS_FRESH:80', @('SOY'), @('vegetarian')),
    @('Cháo trứng rau ngót', 'breakfast', 'RICE_WHITE_RAW:50,CHICKEN_EGG_RAW:50,SAUROPUS_FRESH:80', @('EGG'), @('vegetarian')),
    @('Cháo đậu phụ cà chua', 'breakfast', 'RICE_WHITE_RAW:50,TOFU_BOILED:90,TOMATO_FRESH:100', @('SOY'), @('vegetarian')),
    @('Miến đậu phụ cải thìa', 'breakfast', 'GLASS_NOODLE_DRY:50,TOFU_BOILED:90,BOK_CHOY_FRESH:100', @('SOY'), @('vegetarian')),
    @('Cơm · bò hấp gừng · cải thìa', 'lunch', 'RICE_WHITE_RAW:75,BEEF_LEAN_RAW:80,GINGER_FRESH:5,BOK_CHOY_FRESH:150', @(), @()),
    @('Cơm · gà hấp nấm · bí xanh', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_RAW:80,SHIITAKE_DRY:3,WINTER_MELON_FRESH:150', @(), @()),
    @('Cơm · cá rô phi hấp · rau muống', 'lunch', 'RICE_WHITE_RAW:75,TILAPIA_RAW:100,GINGER_FRESH:5,WATER_SPINACH_FRESH:150', @('FISH'), @()),
    @('Cơm · thịt lợn hấp · rau ngót', 'lunch', 'RICE_WHITE_RAW:75,PORK_LEAN_RAW:80,SAUROPUS_FRESH:150', @(), @()),
    @('Cơm · thịt lợn · cải thìa', 'lunch', 'RICE_WHITE_RAW:75,PORK_LEAN_RAW:80,BOK_CHOY_FRESH:150', @(), @()),
    @('Cơm · cá trắm · cải soong', 'lunch', 'RICE_WHITE_RAW:75,GRASS_CARP_RAW:100,WATERCRESS_FRESH:150', @('FISH'), @()),
    @('Cơm · tôm biển · bí xanh', 'lunch', 'RICE_WHITE_RAW:75,SEA_SHRIMP_RAW:100,WINTER_MELON_FRESH:150', @('CRUSTACEAN'), @()),
    @('Cơm · trứng · đậu phụ · rau muống', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_EGG_RAW:50,TOFU_BOILED:80,WATER_SPINACH_FRESH:150', @('EGG','SOY'), @('vegetarian')),
    @('Cơm · đậu phụ cà chua · mồng tơi', 'lunch', 'RICE_WHITE_RAW:75,TOFU_BOILED:120,TOMATO_FRESH:80,MALABAR_SPINACH_FRESH:150', @('SOY'), @('vegetarian')),
    @('Cơm · gà · mướp đắng', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_RAW:80,BITTER_MELON_FRESH:150', @(), @()),
    @('Cơm · bò · hành tây · cải xanh', 'lunch', 'RICE_WHITE_RAW:75,BEEF_LEAN_RAW:80,ONION_FRESH:30,MUSTARD_GREENS_FRESH:150', @(), @()),
    @('Cơm · ngan gừng · rau khoai lang', 'lunch', 'RICE_WHITE_RAW:75,DUCK_RAW:80,GINGER_FRESH:5,SWEET_POTATO_LEAVES_FRESH:150', @(), @()),
    @('Cơm · cá bống cà chua · cải thìa', 'lunch', 'RICE_WHITE_RAW:75,GOBY_RAW:100,TOMATO_FRESH:50,BOK_CHOY_FRESH:150', @('FISH'), @()),
    @('Cơm · bê · hành tây · đậu cô ve', 'lunch', 'RICE_WHITE_RAW:75,VEAL_LEAN_RAW:80,ONION_FRESH:30,GREEN_BEANS_BOILED:150', @(), @()),
    @('Cơm · cá rô phi cà chua · cải xanh', 'lunch', 'RICE_WHITE_RAW:75,TILAPIA_RAW:100,TOMATO_FRESH:50,MUSTARD_GREENS_FRESH:150', @('FISH'), @()),
    @('Cơm · đậu phụ nấm · cải soong', 'lunch', 'RICE_WHITE_RAW:75,TOFU_BOILED:120,SHIITAKE_DRY:3,WATERCRESS_FRESH:150', @('SOY'), @('vegetarian')),
    @('Cơm · trứng hấp · đậu phụ · cải thìa', 'dinner', 'RICE_WHITE_RAW:60,CHICKEN_EGG_RAW:50,TOFU_BOILED:80,BOK_CHOY_FRESH:150', @('EGG','SOY'), @('vegetarian')),
    @('Cơm · cá trắm hấp gừng · mồng tơi', 'dinner', 'RICE_WHITE_RAW:60,GRASS_CARP_RAW:100,GINGER_FRESH:5,MALABAR_SPINACH_FRESH:150', @('FISH'), @()),
    @('Cơm · thịt bò hấp · đậu cô ve', 'dinner', 'RICE_WHITE_RAW:60,BEEF_LEAN_RAW:80,GREEN_BEANS_BOILED:150', @(), @()),
    @('Cơm · gà hấp · cải soong', 'dinner', 'RICE_WHITE_RAW:60,CHICKEN_RAW:80,WATERCRESS_FRESH:150', @(), @()),
    @('Cơm · thịt lợn · bí xanh', 'dinner', 'RICE_WHITE_RAW:60,PORK_LEAN_RAW:75,WINTER_MELON_FRESH:150', @(), @()),
    @('Cơm · cá rô phi cà chua · cải soong', 'dinner', 'RICE_WHITE_RAW:60,TILAPIA_RAW:90,TOMATO_FRESH:50,WATERCRESS_FRESH:150', @('FISH'), @()),
    @('Cơm · tôm biển · mồng tơi', 'dinner', 'RICE_WHITE_RAW:60,SEA_SHRIMP_RAW:90,MALABAR_SPINACH_FRESH:150', @('CRUSTACEAN'), @()),
    @('Cơm · đậu phụ nấm · cải xanh', 'dinner', 'RICE_WHITE_RAW:60,TOFU_BOILED:120,SHIITAKE_DRY:3,MUSTARD_GREENS_FRESH:150', @('SOY'), @('vegetarian')),
    @('Cơm · trứng cà chua · rau muống', 'dinner', 'RICE_WHITE_RAW:60,CHICKEN_EGG_RAW:60,TOMATO_FRESH:80,WATER_SPINACH_FRESH:150', @('EGG'), @('vegetarian')),
    @('Cơm · ngan nấm · cải thìa', 'dinner', 'RICE_WHITE_RAW:60,DUCK_RAW:75,SHIITAKE_DRY:3,BOK_CHOY_FRESH:150', @(), @()),
    @('Cơm · bò hành tây · bí xanh', 'dinner', 'RICE_WHITE_RAW:60,BEEF_LEAN_RAW:75,ONION_FRESH:30,WINTER_MELON_FRESH:150', @(), @()),
    @('Cơm · bê hấp gừng · rau khoai lang', 'dinner', 'RICE_WHITE_RAW:60,VEAL_LEAN_RAW:75,GINGER_FRESH:5,SWEET_POTATO_LEAVES_FRESH:150', @(), @()),
    @('Cơm · cá bống gừng · rau ngót', 'dinner', 'RICE_WHITE_RAW:60,GOBY_RAW:90,GINGER_FRESH:5,SAUROPUS_FRESH:150', @('FISH'), @()),
    @('Cơm · gà hấp gừng · mướp đắng', 'dinner', 'RICE_WHITE_RAW:60,CHICKEN_RAW:75,GINGER_FRESH:5,BITTER_MELON_FRESH:150', @(), @()),
    @('Cơm · cá trắm cà chua · đậu cô ve', 'dinner', 'RICE_WHITE_RAW:60,GRASS_CARP_RAW:90,TOMATO_FRESH:50,GREEN_BEANS_BOILED:150', @('FISH'), @()),
    @('Cơm · đậu phụ · cà chua · cải soong', 'dinner', 'RICE_WHITE_RAW:60,TOFU_BOILED:120,TOMATO_FRESH:80,WATERCRESS_FRESH:150', @('SOY'), @('vegetarian'))
)
function StableId([string]$value) {
    $hash = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))
    return ([guid]::new([byte[]]$hash[0..15])).ToString()
}
$citationId = 'CARESITTER_VARIETY_ADAPTATION_V2'
$bundle.citations += @{
    id=$citationId; title='Công thức phối hợp CareSitter v2'; organization='CareSitter'; year=2026
    edition='2'; chapter='Bữa ăn người lớn - catalog local'; printedPages=$null; pdfPages=$null
    locator='backend/scripts/build-nutrition-variety-catalog.ps1'
    reference='Công thức điều chỉnh của CareSitter; dưỡng chất ước tính từ định lượng và snapshot Viện Dinh dưỡng, không phải thực đơn nguyên văn từ sách.'
    verifiedOn='2026-10-27'
}
foreach ($spec in $specs) {
    $ingredients = @()
    foreach ($entry in $spec[2].Split(',')) {
        $code, $amount = $entry.Split(':'); $food = $foods[$code]
        if (!$food -or $food.perUnit -ne 'g') { throw "Unsupported food: $code" }
        $ingredients += @{code=$code;name=$food.nameVi;amount=[decimal]$amount;unit='g';basis=$food.basis}
    }
    $nutrients = @{}
    foreach ($key in @('energy_kcal','protein_g','carbohydrate_g','fat_g','fiber_g','sodium_mg')) {
        [decimal]$sum = 0
        foreach ($ingredient in $ingredients) {
            $food = $foods[$ingredient.code]; $value = $food.nutrients[$key].value
            if ($null -eq $value) { throw "Missing nutrient $key for $($ingredient.code)" }
            $sum += [decimal]$value * $ingredient.amount / [decimal]$food.perAmount
        }
        $nutrients[$key] = [Math]::Round($sum, 2, [MidpointRounding]::AwayFromZero)
    }
    $imageSource = @($bundle.recipes | Where-Object { $_.payload.mealType -eq $spec[1] })[0].payload
    $method = if ($spec[0].StartsWith('Miến')) {
        'Ngâm hoặc trụng miến vừa mềm; sơ chế nguyên liệu còn lại, loại bỏ xương nếu có và nấu chín hoàn toàn.'
    } elseif ($spec[0].StartsWith('Cháo')) {
        'Nấu gạo với nước thành cháo; sơ chế nguyên liệu còn lại, loại bỏ xương nếu có và nấu chín hoàn toàn cùng cháo.'
    } else {
        'Nấu gạo thành cơm. Sơ chế thịt/cá/trứng, loại bỏ xương nếu có và hấp hoặc luộc chín hoàn toàn; rau nấu chín, nguyên liệu đã chín được làm nóng lại.'
    }
    $recipe = @{
        recipeId=(StableId "caresitter-variety-recipe-v1:$($spec[0])");version=1
        payload=@{
            versionId=(StableId "caresitter-variety-version-v1:$($spec[0])");name=$spec[0];mealType=$spec[1];servings=1
            imageUrl=$imageSource.imageUrl;imageAlt="Ảnh minh hoạ $($spec[0])"
            ingredients=$ingredients;allergens=@($spec[3]);nutrients=$nutrients;allergenDataComplete=$true;dietaryPatterns=@($spec[4])
            sourceRecipeNote='Sách không đề cập công thức chế biến cho món phối hợp này; hướng dẫn bên dưới do CareSitter xây dựng cho demo.'
            preparationSteps=@(
                'Cân nguyên liệu theo định lượng và trạng thái sống/chín ghi trong danh sách; lượng gạo là gạo khô.',
                $method,
                'Công thức phối hợp do CareSitter xây dựng, không phải công thức nguyên văn trong sách. Dưỡng chất ước tính từ nguyên liệu; chưa gồm gia vị bổ sung hoặc hao hụt khi chế biến.'
            )
            sources=@($citationId,'VIETNAM_FOOD_COMPOSITION_2017')
        }
    }
    $bundle.recipes += $recipe
}
$uniqueVersionCount = @($bundle.recipes.payload.versionId | Select-Object -Unique).Count
if ($bundle.recipes.Count -ne 60 -or $uniqueVersionCount -ne 60) {
    throw "Unexpected catalog size or duplicate identity: recipes=$($bundle.recipes.Count), uniqueVersions=$uniqueVersionCount."
}
foreach ($type in @('breakfast','lunch','dinner')) {
    if (@($bundle.recipes | Where-Object { $_.payload.mealType -eq $type }).Count -ne 20) { throw "Unexpected $type count." }
}
$output = "$catalog/drafts/adult-baseline-variety-demo.bundle.json"
function CanonicalObject($value) {
    if ($value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in ($value.Keys | Sort-Object)) { $result[$key] = CanonicalObject $value[$key] }
        return $result
    }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        $items = @($value | ForEach-Object { CanonicalObject $_ })
        return ,$items
    }
    return $value
}
CanonicalObject $bundle | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
Write-Output "Generated 60 meals (20 per meal type): $output"
