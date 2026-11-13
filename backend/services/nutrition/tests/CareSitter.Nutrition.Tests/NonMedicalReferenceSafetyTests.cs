using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class NonMedicalReferenceSafetyTests
{
    [Theory]
    [InlineData("source_and_clinical")]
    [InlineData("non_medical_reference")]
    public async Task Missing_allergen_data_remains_excluded_before_retrieval(string policy)
    {
        var recipes = new[] { Meal("breakfast"), Meal("lunch"), Meal("dinner") }
            .Select(recipe => recipe with { ReviewPolicy = policy }).ToArray();
        recipes[0] = recipes[0] with { AllergenDataComplete = false };
        var facts = new[] { new HealthFact("food_allergy", "SHRIMP", "Synthetic", "present", "current", "allergies/0", "Synthetic", "beneficiary") };
        var result = await new MealRecommendationEngine(new MustNotRetrieve(), new MustNotRank())
            .RecommendAsync(new(1, recipes, facts, [], "regular", "maintain"), CancellationToken.None);
        Assert.Null(result.Meals);
        Assert.Contains("constraints_not_matched", result.Trace.Warnings);
        Assert.Empty(result.Trace.Evidence);
    }

    [Theory]
    [InlineData("source_and_clinical")]
    [InlineData("non_medical_reference")]
    public void Special_profiles_keep_professional_guidance_and_cannot_complete_a_menu(string policy)
    {
        foreach (var scenario in new[] { "condition", "special_needs", "child", "pregnancy" })
        {
            var snapshot = EligibilityTests.Healthy();
            if (scenario == "child") snapshot = snapshot with { DateOfBirth = DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-10) };
            if (scenario is "condition" or "pregnancy") snapshot = snapshot with { HealthHistory = EligibilityTests.History(conditionsStatus: "reported_present") };
            var health = HealthSnapshotNormalizer.Normalize(snapshot, []);
            if (scenario == "special_needs") health = health with { SpecialNeeds = ["TUBE_FEEDING"] };
            HealthFact[] facts = scenario is "condition" or "pregnancy"
                ? [new("condition", scenario == "pregnancy" ? "PREGNANCY" : "KIDNEY_DISEASE", "Synthetic", "present", "current", "conditions/0", "Synthetic", "beneficiary")]
                : [];
            var decision = NutritionEligibilityPolicy.Evaluate(snapshot, health, facts, [], true);
            Assert.Equal("needs_professional_guidance", decision.State);
            var meals = new[] { Meal("breakfast"), Meal("lunch"), Meal("dinner") }
                .Select(recipe => recipe with { ReviewPolicy = policy }).ToArray();
            var assessment = new AssessmentPayload(1, snapshot, facts, decision, CatalogRevision: 1);
            var prepared = new MealPreparation(Guid.NewGuid(), DateOnly.FromDateTime(DateTime.UtcNow), assessment,
                null, meals, [], [], decision, 1, health);
            var payload = prepared.Complete(meals);
            Assert.Empty(payload.Meals);
            Assert.Equal("needs_professional_guidance", payload.Decision.State);
            Assert.NotEmpty(payload.Decision.RequiredGuidance);
        }
    }

    [Theory]
    [InlineData("source_and_clinical", false)]
    [InlineData("non_medical_reference", true)]
    public void Catalog_payload_policy_is_read_without_losing_hash_bound_metadata(string policy, bool reference)
    {
        var recipe = Meal("breakfast") with
        {
            ReviewPolicy = policy,
            IntendedUse = reference ? "academic_reference_non_medical" : "reviewed_nutrition_reference",
            ClinicalReviewPerformed = !reference, IndependentClinicalReview = !reference,
            ProductionPublicRelease = false,
            ClinicalReviewNotPerformedReason = reference ? "no_clinical_reviewer_non_medical_reference" : null
        };
        var json = NutritionJson.Write(recipe);
        var permitted = NutritionCatalogReader.ReadRecipePayload(json, true);
        Assert.NotNull(permitted);
        Assert.Equal(json, NutritionJson.Write(permitted));
        if (reference) Assert.Null(NutritionCatalogReader.ReadRecipePayload(json, false));
        else Assert.Equal(policy, NutritionCatalogReader.ReadRecipePayload(json, false)!.ReviewPolicy);
        var missing = System.Text.Json.Nodes.JsonNode.Parse(json)!;
        missing.AsObject().Remove("review_policy");
        Assert.ThrowsAny<Exception>(() => NutritionCatalogReader.ReadRecipePayload(missing.ToJsonString(), true));
    }

    private static Recipe Meal(string meal) => new(Guid.NewGuid(), "Synthetic " + meal, meal, 1,
        [new("RICE", "Synthetic rice", 100, "g", "raw")], [], new() { ["energy_kcal"] = 100 }, ["Synthetic"], ["Synthetic"], true);

    private sealed class MustNotRetrieve : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            throw new InvalidOperationException("Safety gate must run before retrieval.");
    }
    private sealed class MustNotRank : IMealCandidateRanker
    {
        public Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request, CancellationToken ct) =>
            throw new InvalidOperationException("Safety gate must run before ranking.");
    }
}
