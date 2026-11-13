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
$derivedAllergens = @{
    BEEF_LEAN_RAW = 'BEEF'
    CHICKEN_RAW   = 'CHICKEN'
}
$unverifiedCompositeIngredients = @(
    'CHILI_SAUCE',
    'FERMENTED_SOYBEAN_RICE',
    'TOFU_BOILED',
    'RICE_NOODLE_READY',
    'GLASS_NOODLE_DRY'
)
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
    @('Cơm · đậu phụ · cà chua · cải soong', 'dinner', 'RICE_WHITE_RAW:60,TOFU_BOILED:120,TOMATO_FRESH:80,WATERCRESS_FRESH:150', @('SOY'), @('vegetarian')),
    @('Cơm nắm gà gừng', 'breakfast', 'RICE_WHITE_RAW:60,CHICKEN_RAW:70,GINGER_FRESH:4,SCALLION_FRESH:5,MANDARIN_FRESH:90', @(), @(), 'Nấu cơm. Luộc gà với gừng, xé nhỏ rồi trộn với cơm nóng và hành đã chần. Nắm thành phần nhỏ, dùng ngay với quýt.'),
    @('Cơm cuộn trứng cải thìa', 'breakfast', 'RICE_WHITE_RAW:55,CHICKEN_EGG_RAW:70,BOK_CHOY_FRESH:80,PEANUT_OIL:4,APPLE_FRESH:100', @('EGG','PEANUT'), @('vegetarian'), 'Nấu cơm và luộc cải thìa, để ráo rồi thái nhỏ. Tráng trứng chín với dầu lạc. Trải cơm và cải lên trứng, cuộn lại, ăn kèm táo.'),
    @('Cơm trộn đậu cô ve, trứng và nấm', 'breakfast', 'RICE_WHITE_RAW:60,CHICKEN_EGG_RAW:65,GREEN_BEANS_BOILED:80,SHIITAKE_DRY:4,PEANUT_OIL:4', @('EGG','PEANUT'), @('vegetarian'), 'Nấu cơm. Ngâm nấm cho mềm rồi băm nhỏ. Xào chín nấm với dầu lạc, thêm đậu cô ve đã luộc và trứng. Đảo đến khi trứng chín rồi trộn với cơm.'),
    @('Cơm rang tôm và cải thìa', 'breakfast', 'RICE_WHITE_RAW:60,SEA_SHRIMP_RAW:70,BOK_CHOY_FRESH:80,GARLIC_FRESH:3,PEANUT_OIL:5', @('CRUSTACEAN','PEANUT'), @(), 'Nấu cơm và xới cho tơi. Bóc vỏ, bỏ chỉ lưng tôm rồi cắt nhỏ. Xào tỏi, tôm và cải với dầu lạc đến khi chín, cho cơm vào đảo nóng đều.'),
    @('Cháo cá bống bí xanh', 'breakfast', 'RICE_WHITE_RAW:55,GOBY_RAW:75,WINTER_MELON_FRESH:100,GINGER_FRESH:4', @('FISH'), @(), 'Ninh gạo với nước. Hấp chín cá với gừng, gỡ kỹ xương và lấy thịt cá. Thêm bí cắt nhỏ vào cháo, nấu mềm rồi cho cá vào đun nóng lại.'),
    @('Súp gạo thịt nạc và đậu cô ve', 'breakfast', 'RICE_WHITE_RAW:55,PORK_LEAN_RAW:70,GREEN_BEANS_BOILED:100,ONION_FRESH:20', @(), @(), 'Nấu gạo với nước thành súp. Băm thịt nạc và hành tây, cho vào nồi nấu chín. Cắt nhỏ đậu cô ve đã luộc, cho vào sau cùng và đun nóng.'),
    @('Cơm với canh gà bí xanh', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_RAW:100,WINTER_MELON_FRESH:150,SCALLION_FRESH:6,GINGER_FRESH:4', @(), @(), 'Nấu cơm riêng. Cắt gà bỏ xương thành miếng nhỏ và đun với gừng trong nước đến khi thịt chín. Cho bí vào nấu mềm, thêm hành lá và dùng với cơm.', 'MNMN_CANH_GA_BI_XANH'),
    @('Cơm · bò xào đậu cô ve · cà chua', 'lunch', 'RICE_WHITE_RAW:75,BEEF_LEAN_RAW:85,GREEN_BEANS_BOILED:120,TOMATO_FRESH:100,GARLIC_FRESH:3,PEANUT_OIL:6', @('PEANUT'), @(), 'Nấu cơm. Thái bò mỏng, phi tỏi với dầu lạc rồi xào thịt chín. Cho đậu đã luộc và cà chua cắt miếng vào đảo nóng, dọn cùng cơm.'),
    @('Cơm · trứng đúc nấm · rau khoai lang', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_EGG_RAW:100,SHIITAKE_DRY:5,SWEET_POTATO_LEAVES_FRESH:130,PEANUT_OIL:5', @('EGG','PEANUT'), @('vegetarian'), 'Nấu cơm, luộc rau khoai lang. Ngâm mềm nấm rồi băm nhỏ, trộn với trứng. Tráng hỗn hợp bằng dầu lạc cho chín đều hai mặt.'),
    @('Cơm · trứng hấp hành tây · canh mồng tơi', 'lunch', 'RICE_WHITE_RAW:75,CHICKEN_EGG_RAW:100,ONION_FRESH:25,MALABAR_SPINACH_FRESH:150', @('EGG'), @('vegetarian'), 'Nấu cơm. Đánh trứng với hành tây thái nhỏ và một ít nước, hấp đến khi trứng đông chín. Nấu mồng tơi với nước thành canh.'),
    @('Cơm · tôm xào cải xanh và nấm', 'lunch', 'RICE_WHITE_RAW:75,SEA_SHRIMP_RAW:100,MUSTARD_GREENS_FRESH:130,SHIITAKE_DRY:5,GARLIC_FRESH:3,PEANUT_OIL:6', @('CRUSTACEAN','PEANUT'), @(), 'Nấu cơm. Bóc vỏ và bỏ chỉ lưng tôm. Ngâm mềm nấm, cắt lát. Dùng dầu lạc xào tỏi, tôm, nấm và cải đến khi chín, ăn với cơm.'),
    @('Cơm · thịt nạc hấp gừng · canh cải soong', 'lunch', 'RICE_WHITE_RAW:75,PORK_LEAN_RAW:85,GINGER_FRESH:5,WATERCRESS_FRESH:150,TOMATO_FRESH:60', @(), @(), 'Nấu cơm. Hấp thịt thái lát với gừng đến khi chín. Đun cà chua với nước, thêm cải soong và nấu rau chín thành canh.'),
    @('Cơm · cá rô phi hấp mồng tơi', 'dinner', 'RICE_WHITE_RAW:65,TILAPIA_RAW:100,MALABAR_SPINACH_FRESH:140,GARLIC_FRESH:3,SCALLION_FRESH:5', @('FISH'), @(), 'Nấu cơm. Hấp phi lê cá với tỏi và hành đến khi chín, kiểm tra và gỡ xương. Luộc mồng tơi, để ráo rồi dọn với cá và cơm.', 'MNMN_CA_HAP_MONG_TOI'),
    @('Cơm · trứng cuộn cải xanh · canh cà chua', 'dinner', 'RICE_WHITE_RAW:65,CHICKEN_EGG_RAW:100,MUSTARD_GREENS_FRESH:100,TOMATO_FRESH:100,PEANUT_OIL:5', @('EGG','PEANUT'), @('vegetarian'), 'Nấu cơm. Chần cải xanh, vắt ráo và thái nhỏ. Tráng trứng với dầu lạc, thêm cải và cuộn khi trứng đã chín. Nấu cà chua với nước để làm canh.'),
    @('Cơm · trứng hấp nấm · bí xanh luộc', 'dinner', 'RICE_WHITE_RAW:65,CHICKEN_EGG_RAW:100,SHIITAKE_DRY:5,WINTER_MELON_FRESH:150,SCALLION_FRESH:5', @('EGG'), @('vegetarian'), 'Nấu cơm. Ngâm nấm, thái nhỏ rồi trộn với trứng, hành và một ít nước. Hấp đến khi trứng đông chín. Luộc bí xanh và dùng cùng cơm.'),
    @('Cơm với canh tôm rau ngót', 'dinner', 'RICE_WHITE_RAW:65,SEA_SHRIMP_RAW:100,SAUROPUS_FRESH:130,ONION_FRESH:20', @('CRUSTACEAN'), @(), 'Nấu cơm. Tôm bóc vỏ, bỏ chỉ lưng rồi băm nhỏ. Đun hành tây và tôm trong nước đến khi tôm chín, cho rau ngót vào và nấu mềm.'),
    @('Cơm · gà áp chảo tỏi · đậu cô ve', 'dinner', 'RICE_WHITE_RAW:65,CHICKEN_RAW:90,GARLIC_FRESH:4,GREEN_BEANS_BOILED:140,PEANUT_OIL:5', @('PEANUT'), @(), 'Nấu cơm. Cắt gà thành miếng mỏng, áp chảo hai mặt với dầu lạc đến khi chín kỹ. Thêm tỏi và đậu đã luộc, đảo nóng rồi dọn với cơm.'),
    @('Cơm · thịt nạc cuộn cải thìa · nấm hấp', 'dinner', 'RICE_WHITE_RAW:65,PORK_LEAN_RAW:90,BOK_CHOY_FRESH:150,SHIITAKE_DRY:6,SCALLION_FRESH:5', @(), @(), 'Nấu cơm. Chần lá cải cho mềm, bọc thịt nạc băm trộn hành thành cuốn nhỏ. Ngâm nấm cho mềm rồi hấp cùng cuốn đến khi nhân chín kỹ.')
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
$authoredCitationId = 'CARESITTER_HOME_MEALS_DEMO'
$bundle.citations += @{
    id=$authoredCitationId; title='Công thức CareSitter'; organization='CareSitter'; year=2026
    edition=$null; chapter=$null; printedPages=$null; pdfPages=$null
    locator='Công thức một phần'; reference='Công thức do CareSitter biên soạn cho bản demo. Dưỡng chất ước tính từ định lượng nguyên liệu.'
    verifiedOn='2026-11-11'
}
$cookingReferences = @{
    MNMN_CANH_GA_BI_XANH = @{ chapter='Canh gà bí xanh'; url='https://monngonmoingay.com/canh-ga-bi-xanh/' }
    MNMN_CA_HAP_MONG_TOI = @{ chapter='Cá hấp mồng tơi'; url='https://monngonmoingay.com/ca-hap-mong-toi/' }
}
foreach ($id in ($cookingReferences.Keys | Sort-Object)) {
    $reference = $cookingReferences[$id]
    $bundle.citations += @{
        id=$id; title='Món Ngon Mỗi Ngày'; organization='Ajinomoto Việt Nam'; year=2026
        edition='Trang web, năm đối chiếu'; chapter=$reference.chapter; printedPages=$null; pdfPages=$null
        locator='Công thức gốc trực tuyến'; reference=$reference.url; verifiedOn='2026-11-11'
    }
}
foreach ($spec in $specs) {
    $ingredients = @()
    foreach ($entry in $spec[2].Split(',')) {
        $code, $amount = $entry.Split(':'); $food = $foods[$code]
        if (!$food -or $food.perUnit -ne 'g') { throw "Unsupported food: $code" }
        $ingredients += @{code=$code;name=$food.nameVi;amount=[decimal]$amount;unit='g';basis=$food.basis}
    }
    $allergens = @($spec[3])
    foreach ($ingredient in $ingredients) {
        $derived = $derivedAllergens[$ingredient.code]
        if ($derived -and $allergens -notcontains $derived) { $allergens += $derived }
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
    $method = if ($spec.Count -ge 6) {
        $spec[5]
    } elseif ($spec[0].StartsWith('Miến')) {
        'Ngâm hoặc trụng miến vừa mềm; sơ chế nguyên liệu còn lại, loại bỏ xương nếu có và nấu chín hoàn toàn.'
    } elseif ($spec[0].StartsWith('Cháo')) {
        'Nấu gạo với nước thành cháo; sơ chế nguyên liệu còn lại, loại bỏ xương nếu có và nấu chín hoàn toàn cùng cháo.'
    } else {
        'Nấu gạo thành cơm. Sơ chế thịt/cá/trứng, loại bỏ xương nếu có và hấp hoặc luộc chín hoàn toàn; rau nấu chín, nguyên liệu đã chín được làm nóng lại.'
    }
    $sourceNote = 'Sách không đề cập công thức chế biến cho món phối hợp này; hướng dẫn bên dưới do CareSitter xây dựng cho demo.'
    $preparationNote = 'Công thức phối hợp do CareSitter xây dựng, không phải công thức nguyên văn trong sách. Dưỡng chất ước tính từ nguyên liệu; chưa gồm gia vị bổ sung hoặc hao hụt khi chế biến.'
    $sources = @($citationId,'VIETNAM_FOOD_COMPOSITION_2017')
    $imageUrl = $imageSource.imageUrl
    $imageAlt = "Ảnh minh hoạ $($spec[0])"
    if ($spec.Count -ge 6) {
        $sources = @($authoredCitationId,'VIETNAM_FOOD_COMPOSITION_2017')
        $imageUrl = $null
        $imageAlt = $null
        $sourceNote = 'Công thức một phần do CareSitter biên soạn cho bản demo.'
        $preparationNote = 'Dùng nước để nấu theo hướng dẫn. Dưỡng chất ước tính từ lượng nguyên liệu đã ghi và chưa tính hao hụt khi nấu.'
    }
    if ($spec.Count -ge 7) {
        $sources += $spec[6]
        $sourceNote = 'Tham khảo cách nấu từ Món Ngon Mỗi Ngày — Ajinomoto Việt Nam. CareSitter điều chỉnh nguyên liệu và định lượng cho một phần.'
    }
    $recipe = @{
        recipeId=(StableId "caresitter-variety-recipe-v1:$($spec[0])");version=1
        payload=@{
            versionId=(StableId "caresitter-variety-version-v1:$($spec[0])");name=$spec[0];mealType=$spec[1];servings=1
            imageUrl=$imageUrl;imageAlt=$imageAlt
            ingredients=$ingredients;allergens=$allergens;nutrients=$nutrients;allergenDataComplete=$true;dietaryPatterns=@($spec[4])
            sourceRecipeNote=$sourceNote
            preparationSteps=@(
                'Cân nguyên liệu theo định lượng và trạng thái sống/chín ghi trong danh sách; lượng gạo là gạo khô.',
                $method,
                $preparationNote
            )
            sources=$sources
        }
    }
    $bundle.recipes += $recipe
}
foreach ($version in $bundle.recipes) {
    $recipeAllergens = @($version.payload.allergens)
    foreach ($ingredient in $version.payload.ingredients) {
        $derived = $derivedAllergens[$ingredient.code]
        if ($derived -and $recipeAllergens -notcontains $derived) { $recipeAllergens += $derived }
    }
    $version.payload.allergens = $recipeAllergens
    if (@($version.payload.ingredients | Where-Object { $unverifiedCompositeIngredients -contains $_.code }).Count -gt 0) {
        $version.payload.allergenDataComplete = $false
    }
}
$imageManifest = Get-Content -LiteralPath "$catalog/sources/nutrition-recipe-images.json" -Raw | ConvertFrom-Json -AsHashtable
$imagesByVersion = @{}
foreach ($entry in $imageManifest.recipes) {
    if ($imagesByVersion.ContainsKey($entry.recipeVersionId)) { throw 'Duplicate recipe image mapping.' }
    $imagesByVersion[$entry.recipeVersionId] = $entry
}
foreach ($version in $bundle.recipes) {
    $entry = $imagesByVersion[$version.payload.versionId]
    if (!$entry -or $entry.name -ne $version.payload.name -or $entry.assetKeys.Count -lt 1 -or $entry.assetKeys.Count -gt 3) {
        throw "Missing or stale recipe image mapping: $($version.payload.name)"
    }
    $images = @()
    foreach ($assetKey in $entry.assetKeys) {
        $asset = $imageManifest.assets[$assetKey]
        if (!$asset -or !$asset.url -or !$asset.url.StartsWith('https://res.cloudinary.com/') -or !$asset.fileSha256) {
            throw "Upload and verify the image before generating the catalog: $assetKey"
        }
        $images += @{
            url=$asset.url; dishName=$asset.dishName; sourceUrl=$asset.sourceUrl
            attribution=$asset.attribution; matchKind=$asset.matchKind
        }
    }
    $version.payload.images = $images
    $version.payload.imageUrl = $images[0].url
    $version.payload.imageAlt = "Ảnh tham khảo $($images[0].dishName)"
}
$uniqueVersionCount = @($bundle.recipes.payload.versionId | Select-Object -Unique).Count
if ($bundle.recipes.Count -ne 78 -or $uniqueVersionCount -ne 78) {
    throw "Unexpected catalog size or duplicate identity: recipes=$($bundle.recipes.Count), uniqueVersions=$uniqueVersionCount."
}
foreach ($type in @('breakfast','lunch','dinner')) {
    if (@($bundle.recipes | Where-Object { $_.payload.mealType -eq $type }).Count -ne 26) { throw "Unexpected $type count." }
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
Write-Output "Generated 78 meals (26 per meal type): $output"
