using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class EligibilityTests
{
    internal static BeneficiaryHealthSnapshot Healthy(long revision = 1) => new(Guid.NewGuid(), revision, null,
        "reported_none", DateTimeOffset.UtcNow, null, null, null, null,
        History(), null, null, null);

    internal static JsonElement History(string conditionsStatus = "reported_none", string medicationsStatus = "reported_none") =>
        JsonSerializer.SerializeToElement(new { nutrition = new { schemaVersion = 1, conditionsStatus, medicationsStatus,
            feedingRoute = "oral", swallowingStatus = "normal", fluidRestriction = "none", electrolyteRestriction = "none" } });

    [Fact]
    public void Structured_input_needs_no_text_and_confirmation_is_not_eligibility()
    {
        var source = Healthy(); var health = HealthSnapshotNormalizer.Normalize(source, []);
        Assert.Empty(health.TextSources);
        Assert.Equal("awaiting_confirmation", NutritionEligibilityPolicy.Evaluate(source, health, [], [], false).State);
        Assert.Equal("eligible", NutritionEligibilityPolicy.Evaluate(source, health, [], [], true).State);
    }

    [Fact]
    public void Missing_medication_and_eating_information_is_not_assumed_normal()
    {
        var source = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new { schemaVersion = 1, conditionsStatus = "reported_none" } }) };
        var health = HealthSnapshotNormalizer.Normalize(source, []);
        var decision = NutritionEligibilityPolicy.Evaluate(source, health, [], [], true);
        Assert.Equal("needs_information", decision.State);
        Assert.Contains("healthHistory/nutrition/medicationsStatus", decision.MissingFields);
        Assert.Contains("healthHistory/nutrition/swallowingStatus", decision.MissingFields);
        Assert.DoesNotContain("generalNote", decision.MissingFields);
    }

    [Theory]
    [InlineData("[{\"name\":\"Fixture\",\"is_active\":true}]", "reported_present", "needs_professional_guidance")]
    [InlineData("[{\"name\":\"Fixture\",\"is_active\":false}]", "reported_none", "eligible")]
    [InlineData("[{\"name\":\"Fixture\"}]", "reported_present", "needs_information")]
    [InlineData("[{\"name\":\"Fixture\",\"is_active\":\"false\"}]", "reported_none", "needs_information")]
    [InlineData("[{\"name\":\"Fixture\",\"is_active\":true}]", "reported_none", "needs_information")]
    [InlineData("[]", "reported_present", "needs_information")]
    public void Medication_status_and_legacy_data_cannot_bypass_review(string medications, string status, string expected)
    {
        var source = Healthy() with { HealthHistory = History(medicationsStatus: status), Medications = JsonSerializer.Deserialize<JsonElement>(medications) };
        var health = HealthSnapshotNormalizer.Normalize(source, []);
        var decision = NutritionEligibilityPolicy.Evaluate(source, health, [], [], true);
        Assert.Equal(expected, decision.State);
        Assert.Empty(health.TextSources);
    }
    [Theory]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("{}")]
    [InlineData("[\"Thuốc\"]")]
    public void Unknown_allergy_is_never_inferred_as_none(string json)
    {
        var s = Healthy() with { AllergyStatus = "unknown", AllergyConfirmedAt = null, Allergies = JsonSerializer.Deserialize<JsonElement>(json) };
        var h = HealthSnapshotNormalizer.Normalize(s, []);
        var d = NutritionEligibilityPolicy.Evaluate(s, h, h.Facts, [], true);
        Assert.Equal("needs_information", d.State); Assert.Contains("foodAllergyStatus", d.MissingFields);
    }
    [Theory]
    [InlineData("feedingRoute", "tube")]
    [InlineData("swallowingStatus", "difficulty")]
    [InlineData("fluidRestriction", "present")]
    [InlineData("electrolyteRestriction", "present")]
    public void Specialized_instructions_cannot_be_bypassed(string key, string value)
    {
        var s = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new Dictionary<string, object> { { "schemaVersion", 1 }, { "conditionsStatus", "reported_none" }, { key, value } } }) };
        var h = HealthSnapshotNormalizer.Normalize(s, []);
        Assert.Equal("needs_professional_guidance", NutritionEligibilityPolicy.Evaluate(s, h, [], [], true).State);
    }
    [Fact]
    public void Source_conflict_is_not_resolved_by_overwriting_allergy()
    {
        var s = Healthy(); var h = HealthSnapshotNormalizer.Normalize(s, []);
        var fact = new HealthFact("food_allergy", "SHRIMP", "Tôm", "present", "current", "allergies/0", "Tôm");
        var d = NutritionEligibilityPolicy.Evaluate(s, h, [fact], [], true);
        Assert.Equal("needs_information", d.State); Assert.Contains("allergy_sources_conflict", d.Conflicts);
    }
    [Theory]
    [InlineData("symptom", "present", "current")]
    [InlineData("condition", "uncertain", "current")]
    public void Symptoms_and_uncertain_conditions_do_not_become_treatment(string kind, string assertion, string time)
    {
        var s = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new { schemaVersion = 1, conditionsStatus = "reported_present" } }) };
        var h = HealthSnapshotNormalizer.Normalize(s, []);
        var f = new HealthFact(kind, "TEST", "Test", assertion, time, "generalNote", "Test");
        var d = NutritionEligibilityPolicy.Evaluate(s, h, [f], [], true);
        Assert.NotEqual("eligible", d.State);
    }
    [Fact]
    public void Missing_nutrient_and_combined_daily_constraints_block_meals()
    {
        var meals = new[] { Recipe("breakfast", 10), Recipe("lunch", 10), Recipe("dinner", 10) };
        var facts = new[] { new HealthFact("condition", "A", "A", "present", "current", "conditions/0", "A"), new HealthFact("condition", "B", "B", "present", "current", "conditions/1", "B") };
        var rules = new[] { Rule("A", 40), Rule("B", 25) };
        Assert.False(MealConstraintPolicy.Matches(meals, facts, rules));
        Assert.True(MealConstraintPolicy.Matches(meals, facts, [rules[0]]));
        meals[0] = meals[0] with { Nutrients = new() { { "sodium_mg", null } } };
        Assert.False(MealConstraintPolicy.Matches(meals, facts, [rules[0]]));
    }
    [Fact]
    public void Allergens_in_seasoning_block_recipe_and_empty_catalog_is_not_demo()
    {
        var meals = new[] { Recipe("breakfast", 1) with { Allergens = ["SHRIMP"] }, Recipe("lunch", 1), Recipe("dinner", 1) };
        Assert.False(MealConstraintPolicy.Matches(meals, [new("food_allergy", "SHRIMP", "Tôm", "present", "current", "x", "Tôm")], []));
        Assert.Null(MealConstraintPolicy.Choose([], [], []));
    }
    [Fact]
    public void Fabricated_quote_and_unknown_concept_are_rejected()
    {
        var f = new HealthFact("condition", "A", "A", "present", "current", "note", "invented");
        Assert.False(HealthSnapshotNormalizer.ValidateParserFacts([f], new Dictionary<string, string> { { "note", "Actual text" } }, [new("A", "condition", ["A"], 1)]));
        Assert.False(HealthSnapshotNormalizer.ValidateParserFacts([f with { Quote = "Actual" }], new Dictionary<string, string> { { "note", "Actual text" } }, []));
    }
    internal static Recipe Recipe(string meal, decimal sodium) => new(Guid.NewGuid(), "Fixture recipe", meal, 1,
        [new("RICE", "Gạo", 100, "g", "raw")], [], new() { { "sodium_mg", sodium } }, ["Fixture step"], ["Fixture source"], true);
    private static DietaryRule Rule(string code, decimal maximum) => new(Guid.NewGuid(), code, [], [], new() { { "sodium_mg", maximum } }, ["Fixture rule"]);
    [Theory]
    [InlineData("feedingRoute", "unknown")]
    [InlineData("swallowingStatus", "soft")]
    [InlineData("fluidRestriction", "maybe")]
    public void Unknown_specialized_values_require_clarification(string key, string value)
    {
        var source = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new Dictionary<string, object> { { "schemaVersion", 1 }, { "conditionsStatus", "reported_none" }, { key, value } } }) };
        var health = HealthSnapshotNormalizer.Normalize(source, []);
        var decision = NutritionEligibilityPolicy.Evaluate(source, health, [], [], true);
        Assert.Equal("needs_information", decision.State);
        Assert.Contains("healthHistory/nutrition/" + key, decision.MissingFields);
    }
    [Fact]
    public void Unversioned_structured_data_is_not_implicitly_approved()
    {
        var source = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new { conditionsStatus = "reported_none" } }) };
        var health = HealthSnapshotNormalizer.Normalize(source, []);
        Assert.Contains("healthHistory/nutrition/schemaVersion", health.Unresolved);
    }
    [Theory]
    [InlineData("beneficiary", "đau đầu", false)]
    [InlineData("other", "tăng huyết áp", false)]
    [InlineData("unknown", "tăng huyết áp", false)]
    [InlineData("beneficiary", "tăng huyết áp", true)]
    public void Parser_cannot_turn_symptoms_or_other_person_into_beneficiary_condition(string subject, string quote, bool valid)
    {
        var fact = new HealthFact("condition", "HYPERTENSION", "Tăng huyết áp", "present", "current", "note", quote, subject);
        Assert.Equal(valid, HealthSnapshotNormalizer.ValidateParserFacts([fact], new Dictionary<string, string> { { "note", quote } },
            [new NutritionConcept("HYPERTENSION", "condition", ["tăng huyết áp"], 1)]));
    }
}
