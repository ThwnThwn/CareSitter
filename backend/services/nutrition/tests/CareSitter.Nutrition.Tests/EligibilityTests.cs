using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class EligibilityTests
{
    [Theory]
    [InlineData("MALNUTRITION")]
    [InlineData("SARCOPENIA")]
    [InlineData("KIDNEY_DISEASE")]
    [InlineData("HEART_FAILURE")]
    [InlineData("CANCER")]
    [InlineData("STROKE")]
    public void Clinician_only_condition_cannot_be_enabled_by_a_synthetic_rule(string code)
    {
        Assert.Contains(code, CatalogPolicyVocabulary.ClinicianOnlyConditions);
        var snapshot = Healthy() with { HealthHistory = History(conditionsStatus: "reported_present") };
        var health = HealthSnapshotNormalizer.Normalize(snapshot, []);
        var facts = new[] { new HealthFact("condition", code, code, "present", "current", "conditions/0", code, "beneficiary") };
        var rule = new DietaryRule(Guid.NewGuid(), code, [], [], new(), ["Technical fixture"]);

        var result = NutritionEligibilityPolicy.Evaluate(snapshot, health, facts, [rule], true);

        Assert.Equal("needs_professional_guidance", result.State);
        Assert.Contains(code, result.RequiredGuidance);
    }

    [Fact]
    public void Coexisting_unsupported_condition_reports_only_that_condition()
    {
        var snapshot = Healthy() with { HealthHistory = History(conditionsStatus: "reported_present") };
        var health = HealthSnapshotNormalizer.Normalize(snapshot, []);
        var facts = new[]
        {
            new HealthFact("condition", "HYPERTENSION", "HYPERTENSION", "present", "current", "conditions/0", "fixture", "beneficiary"),
            new HealthFact("condition", "DYSLIPIDEMIA", "DYSLIPIDEMIA", "present", "current", "conditions/1", "fixture", "beneficiary")
        };
        var hypertensionRule = new DietaryRule(Guid.NewGuid(), "HYPERTENSION", [], [], new(), ["Technical fixture"]);

        var result = NutritionEligibilityPolicy.Evaluate(snapshot, health, facts, [hypertensionRule], true);

        Assert.Equal("needs_professional_guidance", result.State);
        Assert.Equal(["DYSLIPIDEMIA"], result.RequiredGuidance);
    }

    internal static BeneficiaryHealthSnapshot Healthy(long revision = 1) => new(Guid.NewGuid(), revision, new DateOnly(1950, 1, 1),
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
        Assert.Equal(3, decision.Questions.Length);
        Assert.Equal("medication-status.v1", decision.Questions[0].Id);
    }
    [Fact]
    public void Pilot_scope_requires_a_known_adult_profile()
    {
        var missing = Healthy() with { DateOfBirth = null };
        var missingHealth = HealthSnapshotNormalizer.Normalize(missing, []);
        Assert.Contains("dateOfBirth", NutritionEligibilityPolicy.Evaluate(missing, missingHealth, [], [], true).MissingFields);
        var child = Healthy() with { DateOfBirth = DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-10) };
        var childHealth = HealthSnapshotNormalizer.Normalize(child, []);
        var decision = NutritionEligibilityPolicy.Evaluate(child, childHealth, [], [], true);
        Assert.Equal("needs_professional_guidance", decision.State);
        Assert.Contains("under_18", decision.RequiredGuidance);
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
        Assert.Equal("food-allergy-status.v1", d.Questions[0].Id);
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
        var fact = new HealthFact("food_allergy", "SHRIMP", "Tôm", "present", "current", "allergies/0", "Tôm", "beneficiary");
        var d = NutritionEligibilityPolicy.Evaluate(s, h, [fact], [], true);
        Assert.Equal("needs_information", d.State); Assert.Contains("allergy_sources_conflict", d.Conflicts);
        Assert.Equal("resolve-food-allergy-conflict.v1", Assert.Single(d.Questions).Id);
    }
    [Fact]
    public void Ambiguous_subject_question_precedes_generic_missing_fields()
    {
        var decision = NutritionDecision.Create("needs_information", ["missing_information"],
            ["foodAllergyStatus", "conditionsStatus"]);
        var unresolved = new HealthUnresolvedStatement("generalNote", "Nhà tôi có người bị gout", 0, 25,
            "ambiguous_subject");

        var enriched = NutritionClarificationPolicy.Attach(decision, [unresolved]);

        Assert.Equal(3, enriched.Questions.Length);
        Assert.Equal("clarify-subject.v1", enriched.Questions[0].Id);
        Assert.Equal("textSources/generalNote", enriched.Questions[0].SourceField);
        Assert.Equal(["beneficiary", "other", "unknown"], enriched.Questions[0].Options);
    }
    [Fact]
    public void Legacy_decision_payload_without_questions_remains_readable()
    {
        const string payload = """
            {
              "state": "needs_information",
              "reasonCodes": ["missing_information"],
              "missingFields": ["foodAllergyStatus"],
              "conflicts": [],
              "requiredGuidance": [],
              "allowedActions": ["edit_health"]
            }
            """;

        var decision = NutritionJson.Read<NutritionDecision>(payload);

        Assert.Empty(decision.Questions);
        Assert.Equal("needs_information", decision.State);
    }
    [Theory]
    [InlineData("symptom", "present", "current")]
    [InlineData("condition", "uncertain", "current")]
    public void Symptoms_and_uncertain_conditions_do_not_become_treatment(string kind, string assertion, string time)
    {
        var s = Healthy() with { HealthHistory = JsonSerializer.SerializeToElement(new { nutrition = new { schemaVersion = 1, conditionsStatus = "reported_present" } }) };
        var h = HealthSnapshotNormalizer.Normalize(s, []);
        var f = new HealthFact(kind, "TEST", "Test", assertion, time, "generalNote", "Test", "beneficiary");
        var d = NutritionEligibilityPolicy.Evaluate(s, h, [f], [], true);
        Assert.NotEqual("eligible", d.State);
    }
    [Fact]
    public void Missing_nutrient_and_combined_daily_constraints_block_meals()
    {
        var meals = new[] { Recipe("breakfast", 10), Recipe("lunch", 10), Recipe("dinner", 10) };
        var facts = new[] { new HealthFact("condition", "A", "A", "present", "current", "conditions/0", "A", "beneficiary"), new HealthFact("condition", "B", "B", "present", "current", "conditions/1", "B", "beneficiary") };
        var rules = new[] { Rule("A", 40), Rule("B", 25) };
        Assert.False(MealConstraintPolicy.Matches(meals, facts, rules));
        Assert.True(MealConstraintPolicy.Matches(meals, facts, [rules[0]]));
        meals[0] = meals[0] with { Nutrients = new() { { "sodium_mg", null } } };
        Assert.False(MealConstraintPolicy.Matches(meals, facts, [rules[0]]));
    }
    [Fact]
    public void Daily_and_per_meal_ranges_are_enforced_together()
    {
        var meals = new[] { Recipe("breakfast", 10), Recipe("lunch", 10), Recipe("dinner", 10) };
        var facts = new[] { new HealthFact("condition", "A", "A", "present", "current", "conditions/0", "A", "beneficiary") };
        var accepted = new DietaryRule(Guid.NewGuid(), "A", [], [], new(), ["Fixture rule"],
        [
            new("sodium_mg", "daily", null, 25, 35),
            new("sodium_mg", "meal", "lunch", 9, 11)
        ]);
        var rejected = accepted with
        {
            NutrientConstraints = [new("sodium_mg", "meal", "lunch", null, 9)]
        };

        Assert.True(MealConstraintPolicy.Matches(meals, facts, [accepted]));
        Assert.False(MealConstraintPolicy.Matches(meals, facts, [rejected]));
    }
    [Fact]
    public void Allergens_in_seasoning_block_recipe_and_empty_catalog_is_not_demo()
    {
        var meals = new[] { Recipe("breakfast", 1) with { Allergens = ["SHRIMP"] }, Recipe("lunch", 1), Recipe("dinner", 1) };
        Assert.False(MealConstraintPolicy.Matches(meals, [new("food_allergy", "SHRIMP", "Tôm", "present", "current", "x", "Tôm", "beneficiary")], []));
        Assert.Null(MealConstraintPolicy.Choose([], [], []));
    }

    [Fact]
    public void Dietary_pattern_filters_recipes_and_goal_changes_energy_ranking()
    {
        Recipe Meal(string meal, string suffix, decimal energy, bool vegetarian) =>
            Recipe(meal, 1) with
            {
                Name = $"{meal} {suffix}",
                Nutrients = new() { ["sodium_mg"] = 1, ["energy_kcal"] = energy },
                DietaryPatterns = vegetarian ? ["vegetarian"] : null
            };
        var recipes = new[]
        {
            Meal("breakfast", "low", 100, true), Meal("breakfast", "high", 200, false),
            Meal("lunch", "low", 200, true), Meal("lunch", "high", 400, false),
            Meal("dinner", "low", 150, true), Meal("dinner", "high", 300, false)
        };

        var lose = MealConstraintPolicy.Choose(recipes, [], [], "regular", "lose")!;
        var gain = MealConstraintPolicy.Choose(recipes, [], [], "regular", "gain")!;
        var vegetarian = MealConstraintPolicy.Choose(recipes, [], [], "vegetarian", "gain")!;

        Assert.Equal(450, lose.Sum(meal => meal.Nutrients["energy_kcal"]));
        Assert.Equal(900, gain.Sum(meal => meal.Nutrients["energy_kcal"]));
        Assert.All(vegetarian, meal => Assert.Contains("vegetarian", meal.DietaryPatterns!));
        Assert.Null(MealConstraintPolicy.Choose(recipes, [], [], "unsupported", "maintain"));
    }

    [Fact]
    public void Structured_preferences_are_normalized_for_meal_selection()
    {
        var source = Healthy() with
        {
            HealthHistory = JsonSerializer.SerializeToElement(new
            {
                nutrition = new
                {
                    schemaVersion = 1,
                    conditionsStatus = "reported_none",
                    medicationsStatus = "reported_none",
                    feedingRoute = "oral",
                    swallowingStatus = "normal",
                    fluidRestriction = "none",
                    electrolyteRestriction = "none",
                    dietaryPattern = "vegetarian",
                    nutritionGoal = "lose"
                }
            })
        };

        var health = HealthSnapshotNormalizer.Normalize(source, []);

        Assert.Equal("vegetarian", health.Evidence["dietaryPattern"]);
        Assert.Equal("lose", health.Evidence["nutritionGoal"]);
        Assert.DoesNotContain("healthHistory/nutrition/dietaryPattern", health.Unresolved);
    }
    internal static Recipe Recipe(string meal, decimal sodium) => new(Guid.NewGuid(), "Fixture recipe", meal, 1,
        [new("RICE", "Gạo", 100, "g", "raw")], [], new() { { "sodium_mg", sodium } }, ["Fixture step"], ["Fixture source"], true);
    private static DietaryRule Rule(string code, decimal maximum) => new(Guid.NewGuid(), code, [], [], new() { { "sodium_mg", maximum } }, ["Fixture rule"]);
    [Fact]
    public void Typed_prerequisite_requires_the_declared_value()
    {
        var source = Healthy() with
        {
            HealthHistory = History(conditionsStatus: "reported_present"),
            ChronicConditions = JsonSerializer.SerializeToElement(new[] { "A" })
        };
        var health = HealthSnapshotNormalizer.Normalize(source, [new("A", "condition", ["A"], 1)]);
        var accepted = new DietaryRule(Guid.NewGuid(), "A", [new("feedingRoute", "equals", ["oral"])], [], new(), ["Fixture rule"]);
        var rejected = accepted with { Prerequisites = [new("feedingRoute", "equals", ["tube"])] };
        Assert.Equal("eligible", NutritionEligibilityPolicy.Evaluate(source, health, health.Facts, [accepted], true).State);
        var decision = NutritionEligibilityPolicy.Evaluate(source, health, health.Facts, [rejected], true);
        Assert.Equal("needs_information", decision.State);
        Assert.Contains("healthHistory/nutrition/feedingRoute", decision.MissingFields);
    }
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
}
