using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class CatalogReleaseValidatorTests
{
    private const string Digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    [Fact]
    public void Reviewed_p2_bundle_with_source_evidence_and_replacement_coverage_is_release_ready()
    {
        var (bundle, evidence) = Package();

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.True(result.IsReleaseReady, string.Join(Environment.NewLine, result.Issues.Select(x => $"{x.Path}: {x.Code}")));
        Assert.Equal(64, Assert.Single(result.Combinations, x => x.ScopeCode == "baseline").ValidCombinations);
        Assert.Equal(64, Assert.Single(result.Combinations, x => x.ScopeCode == "condition-hypertension").ValidCombinations);
        var allergy = Assert.Single(result.Combinations, x => x.ScopeCode == "allergy-soy");
        Assert.Equal(2, allergy.BreakfastOptions);
        Assert.Equal(2, allergy.LunchOptions);
        Assert.Equal(2, allergy.DinnerOptions);
        Assert.Equal(8, allergy.ValidCombinations);
        Assert.Equal(8, Assert.Single(result.Combinations, x => x.ScopeCode == "condition-hypertension-allergy-soy").ValidCombinations);
    }

    [Fact]
    public void Technical_draft_and_unresolved_source_items_cannot_pass_release_gate()
    {
        var (bundle, evidence) = Package();
        evidence = evidence with
        {
            ContentStatus = "technical_draft",
            ClinicalReview = null,
            Recipes = [evidence.Recipes[0] with { UnresolvedItems = ["Gia vị chưa định lượng."] }, .. evidence.Recipes[1..]]
        };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.False(result.IsReleaseReady);
        Assert.Contains(result.Issues, issue => issue.Code == "not_review_ready");
        Assert.Contains(result.Issues, issue => issue.Code == "clinical_review_required");
        Assert.Contains(result.Issues, issue => issue.Code == "unresolved");
    }

    [Fact]
    public void Evidence_must_match_exact_bundle_digest_and_nutrient_values()
    {
        var (bundle, evidence) = Package();
        var first = evidence.Recipes[0];
        evidence = evidence with
        {
            Recipes = [first with
            {
                Nutrients = [first.Nutrients[0] with { Value = first.Nutrients[0].Value + 1 }, .. first.Nutrients[1..]]
            }, .. evidence.Recipes[1..]]
        };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, new string('a', 64));

        Assert.False(result.IsReleaseReady);
        Assert.Contains(result.Issues, issue => issue.Code == "bundle_mismatch");
        Assert.Contains(result.Issues, issue => issue.Code == "value_mismatch");
    }

    [Fact]
    public void Evidence_must_recompute_every_nutrient_used_by_a_v2_rule()
    {
        var (bundle, evidence) = Package();
        var rule = bundle.Rules[0];
        bundle = bundle with
        {
            SchemaVersion = 2,
            Rules = [rule with
            {
                Payload = rule.Payload with
                {
                    NutrientConstraints = [new("sodium_mg", "daily", null, null, 2000)]
                }
            }]
        };
        evidence = evidence with
        {
            RequiredNutrients = evidence.RequiredNutrients.Where(key => key != "sodium_mg").ToArray()
        };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.Contains(result.Issues, issue => issue.Code == "rule_nutrient_missing");
    }

    [Fact]
    public void New_lipid_daily_maximum_requires_provenance_before_release()
    {
        var (bundle, evidence) = Package();
        bundle = bundle with
        {
            Rules = [bundle.Rules[0] with
            {
                Payload = bundle.Rules[0].Payload with
                {
                    // An arbitrary fixture bound: no clinical recommendation is encoded here.
                    DailyMaximums = new() { ["cholesterol_mg"] = 999 }
                }
            }]
        };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.False(result.IsReleaseReady);
        Assert.Contains(result.Issues, issue => issue.Code == "rule_nutrient_missing");
        Assert.Contains(result.Issues, issue => issue.Code == "nutrient_missing");
    }

    [Fact]
    public void Required_nutrient_units_must_match_their_catalog_keys()
    {
        var (bundle, evidence) = Package();
        var first = evidence.Recipes[0];
        evidence = evidence with
        {
            Recipes = [first with
            {
                Nutrients = first.Nutrients.Select(item => item.Key == "sodium_mg" ? item with { Unit = "g" } : item).ToArray()
            }, .. evidence.Recipes[1..]]
        };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.False(result.IsReleaseReady);
        Assert.Contains(result.Issues, issue => issue.Code == "unit_mismatch");
        Assert.Equal("g", CatalogPolicyVocabulary.NutrientUnits["saturated_fat_g"]);
        Assert.Equal("g", CatalogPolicyVocabulary.NutrientUnits["trans_fat_g"]);
        Assert.Equal("mg", CatalogPolicyVocabulary.NutrientUnits["cholesterol_mg"]);
    }

    [Fact]
    public void Unknown_nutrient_cannot_be_added_to_release_evidence_without_a_unit_contract()
    {
        var (bundle, evidence) = Package();
        evidence = evidence with { RequiredNutrients = [.. evidence.RequiredNutrients, "custom_nutrient"] };

        var result = CatalogReleaseValidator.Validate(bundle, evidence, Digest);

        Assert.False(result.IsReleaseReady);
        Assert.Contains(result.Issues, issue => issue.Code == "unsupported_nutrient");
    }

    private static (CatalogBundle Bundle, CatalogReleaseEvidence Evidence) Package()
    {
        const string sourceId = "VIEN_DINH_DUONG_2019";
        var condition = new NutritionConcept("HYPERTENSION", "condition", ["Tăng huyết áp"], 1);
        var soy = new NutritionConcept("SOY", "food_allergy", ["Đậu nành"], 1);
        var rice = new NutritionConcept("RICE", "ingredient", ["Gạo"], 1);
        var recipes = new List<CatalogRecipeVersion>();
        foreach (var mealType in CatalogPolicyVocabulary.MealTypes)
        {
            for (var number = 1; number <= 4; number++)
            {
                var recipe = new Recipe(Guid.NewGuid(), $"{mealType} {number}", mealType, 1,
                    [new("RICE", "Gạo", 100, "g", "raw")], number <= 2 ? [soy.Code] : [], Nutrients(100),
                    ["Nấu chín hoàn toàn."], [sourceId], true);
                recipes.Add(new(Guid.NewGuid(), 1, recipe));
            }
        }

        var rule = new DietaryRule(Guid.NewGuid(), condition.Code,
            [new("medicationsStatus", "equals", ["reported_none"])], [], new() { ["sodium_mg"] = 2000 }, [sourceId]);
        var bundle = new CatalogBundle(1, "adult-hypertension-p2",
            [new("adult-structured-v1", "adult", [condition.Code], "reported_none_only",
                ["KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING", "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION"])],
            [new(sourceId, "Dinh dưỡng lâm sàng", "Viện Dinh dưỡng", 2019, "2019", "Tăng huyết áp", "131-143", "132-144",
                "Thực đơn ví dụ và nguyên tắc dinh dưỡng.", "book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf",
                new(2026, 10, 16), "ABEA34B8A6A63E9EABD25F57141C18BA6AC31012C1D4A8DCC15F9BA68DC7F737")],
            [condition, soy, rice], recipes.ToArray(), [new(Guid.NewGuid(), 1, rule)]);

        var recipeEvidence = recipes.Select(version => new CatalogRecipeEvidence(
            version.Payload.VersionId,
            [new("RICE", sourceId, "Bảng thành phần thực phẩm, mục gạo", "raw",
                version.Payload.Nutrients.ToDictionary(x => x.Key, x => x.Value!.Value), 1, 1)],
            version.Payload.Nutrients.Select(pair => new CatalogNutrientEvidence(
                pair.Key, pair.Value, Unit(pair.Key), "ingredient_sum", [sourceId], $"100 g x {pair.Value}/100 g")).ToArray(),
            [])).ToArray();
        var evidence = new CatalogReleaseEvidence(1, bundle.PackageKey, Digest, "review_ready",
            "Tổng từng chất từ khối lượng ăn được của nguyên liệu.", CatalogReleaseValidator.RequiredP2Nutrients.ToArray(),
            recipeEvidence,
            [new(rule.VersionId, [sourceId], "Chương tăng huyết áp, trang in 131-143", [])],
            new("Nguyễn Văn A", "Bác sĩ dinh dưỡng", new DateTimeOffset(2026, 10, 16, 8, 0, 0, TimeSpan.FromHours(7)), "approved", null));
        return (bundle, evidence);
    }

    private static Dictionary<string, decimal?> Nutrients(decimal sodium) => new()
    {
        ["energy_kcal"] = 360,
        ["protein_g"] = 7,
        ["carbohydrate_g"] = 80,
        ["fat_g"] = 1,
        ["fiber_g"] = 1,
        ["sodium_mg"] = sodium
    };

    private static string Unit(string key) => key switch
    {
        "energy_kcal" => "kcal",
        "sodium_mg" => "mg",
        _ => "g"
    };
}
