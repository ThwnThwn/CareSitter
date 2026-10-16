using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class CatalogBundleTests
{
    [Fact]
    public void Complete_structured_bundle_is_valid()
    {
        var bundle = Bundle();
        var result = CatalogBundleValidator.Validate(bundle);
        Assert.True(result.IsValid, string.Join(Environment.NewLine, result.Issues.Select(x => $"{x.Path}: {x.Code}")));
        Assert.DoesNotContain("sourceDetails", NutritionJson.Write(bundle), StringComparison.Ordinal);
    }

    [Fact]
    public async Task P4_api_smoke_fixture_is_synthetic_valid_and_keeps_source_details_runtime_only()
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", "fixtures", "p4-api-smoke.bundle.json");
        var raw = await File.ReadAllTextAsync(path);
        var bundle = NutritionJson.Read<CatalogBundle>(raw);

        var result = CatalogBundleValidator.Validate(bundle);

        Assert.True(result.IsValid, string.Join(Environment.NewLine, result.Issues.Select(x => $"{x.Path}: {x.Code}")));
        Assert.Equal("p4-api-smoke", bundle.PackageKey);
        Assert.Empty(bundle.Rules);
        Assert.All(bundle.Recipes, recipe => Assert.Null(recipe.Payload.SourceDetails));
        Assert.DoesNotContain("sourceDetails", raw, StringComparison.Ordinal);
    }

    [Fact]
    public void Schema_v2_accepts_daily_and_meal_nutrient_ranges()
    {
        var bundle = Bundle();
        var rule = bundle.Rules[0];
        bundle = bundle with
        {
            SchemaVersion = 2,
            Rules = [rule with
            {
                Payload = rule.Payload with
                {
                    NutrientConstraints =
                    [
                        new("sodium_mg", "daily", null, 20, 100),
                        new("sodium_mg", "meal", "lunch", null, 20)
                    ]
                }
            }]
        };

        var result = CatalogBundleValidator.Validate(bundle);

        Assert.True(result.IsValid, string.Join(Environment.NewLine, result.Issues.Select(x => $"{x.Path}: {x.Code}")));
    }

    [Fact]
    public void Nutrient_constraints_are_versioned_and_reject_invalid_ranges()
    {
        var bundle = Bundle();
        var rule = bundle.Rules[0];
        var constrained = rule with
        {
            Payload = rule.Payload with
            {
                NutrientConstraints = [new("sodium_mg", "daily", null, 101, 100)]
            }
        };

        var v1 = CatalogBundleValidator.Validate(bundle with { Rules = [constrained] });
        var v2 = CatalogBundleValidator.Validate(bundle with { SchemaVersion = 2, Rules = [constrained] });

        Assert.Contains(v1.Issues, issue => issue.Code == "schema_mismatch");
        Assert.Contains(v2.Issues, issue => issue.Code == "range" && issue.Path.Contains("nutrientConstraints", StringComparison.Ordinal));
    }

    [Fact]
    public void Missing_safety_scope_and_unknown_citation_are_rejected()
    {
        var bundle = Bundle();
        bundle = bundle with
        {
            SupportedScopes = [bundle.SupportedScopes[0] with { BlockedSpecialNeeds = [] }],
            Recipes = [bundle.Recipes[0] with { Payload = bundle.Recipes[0].Payload with { Sources = ["UNKNOWN_SOURCE"] } }, .. bundle.Recipes[1..]]
        };
        var result = CatalogBundleValidator.Validate(bundle);
        Assert.False(result.IsValid);
        Assert.Contains(result.Issues, issue => issue.Code == "missing_safety_block");
        Assert.Contains(result.Issues, issue => issue.Code == "unknown_reference" && issue.Path.EndsWith("sources", StringComparison.Ordinal));
    }

    [Fact]
    public void Clinician_only_conditions_can_be_concepts_but_never_published_as_rules()
    {
        var bundle = Bundle();
        var condition = new NutritionConcept("HEART_FAILURE", "condition", ["Suy tim"], 1);
        bundle = bundle with
        {
            Concepts = [.. bundle.Concepts, condition],
            SupportedScopes = [bundle.SupportedScopes[0] with { ConditionCodes = ["HEART_FAILURE"] }],
            Rules = [bundle.Rules[0] with { Payload = bundle.Rules[0].Payload with { ConditionCode = "HEART_FAILURE" } }]
        };

        var result = CatalogBundleValidator.Validate(bundle);

        Assert.Contains(result.Issues, issue => issue.Code == "clinician_only_condition" && issue.Path.EndsWith("conditionCodes", StringComparison.Ordinal));
        Assert.Contains(result.Issues, issue => issue.Code == "clinician_only_condition" && issue.Path.EndsWith("conditionCode", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Seeded_older_adult_conditions_without_rules_always_route_to_professional_guidance()
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", "drafts", "adult-hypertension-p2.bundle.json");
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
        var supported = bundle.SupportedScopes.SelectMany(scope => scope.ConditionCodes).ToHashSet(StringComparer.Ordinal);
        Assert.Equal(["HYPERTENSION"], supported.Order().ToArray());
        var rules = bundle.Rules.Select(version => version.Payload).ToArray();
        var unsupportedConditions = bundle.Concepts.Where(concept => concept.Kind == "condition" && !supported.Contains(concept.Code)).ToArray();
        Assert.Equal(11, unsupportedConditions.Length);

        foreach (var condition in unsupportedConditions)
        {
            var snapshot = EligibilityTests.Healthy() with
            {
                ChronicConditions = JsonSerializer.SerializeToElement(new[] { condition.Aliases[0] }),
                HealthHistory = EligibilityTests.History(conditionsStatus: "reported_present")
            };
            var health = HealthSnapshotNormalizer.Normalize(snapshot, bundle.Concepts);
            var decision = NutritionEligibilityPolicy.Evaluate(snapshot, health, health.Facts, rules, true);
            Assert.Equal("needs_professional_guidance", decision.State);
        }
    }

    [Theory]
    [InlineData("unknown", "equals", false)]
    [InlineData("feedingRoute", "unknown_operator", false)]
    [InlineData("feedingRoute", "equals", true)]
    public void Prerequisite_vocabulary_is_closed(string field, string operation, bool expected)
    {
        var prerequisite = new RulePrerequisite(field, operation, ["oral"]);
        Assert.Equal(expected, CatalogBundleValidator.IsSupported(prerequisite));
    }

    internal static CatalogBundle Bundle()
    {
        const string citation = "VIEN_DINH_DUONG_2019";
        var condition = new NutritionConcept("HYPERTENSION", "condition", ["Tăng huyết áp"], 1);
        var rice = new NutritionConcept("RICE", "ingredient", ["Gạo"], 1);
        CatalogRecipeVersion Recipe(string meal) => new(Guid.NewGuid(), 1,
            new(Guid.NewGuid(), $"Bữa {meal}", meal, 1,
                [new("RICE", "Gạo", 100, "g", "raw")], [], new() { ["sodium_mg"] = 10 },
                ["Nấu chín hoàn toàn."], [citation], true));
        var rule = new DietaryRule(Guid.NewGuid(), condition.Code,
            [new("medicationsStatus", "equals", ["reported_none"])], [], new() { ["sodium_mg"] = 100 }, [citation]);
        return new(1, "adult-hypertension-pilot",
            [new("adult-structured-v1", "adult", [condition.Code], "reported_none_only",
                ["KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING", "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION"])],
            [new(citation, "Dinh dưỡng lâm sàng", "Viện Dinh dưỡng", 2019, "2019", "Pilot fixture", "fixture", "fixture",
                "Fixture only; no clinical threshold is asserted by this test.", "book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf",
                new(2026, 10, 15), "ABEA34B8A6A63E9EABD25F57141C18BA6AC31012C1D4A8DCC15F9BA68DC7F737")],
            [condition, rice], [Recipe("breakfast"), Recipe("lunch"), Recipe("dinner")],
            [new(Guid.NewGuid(), 1, rule)]);
    }
}
