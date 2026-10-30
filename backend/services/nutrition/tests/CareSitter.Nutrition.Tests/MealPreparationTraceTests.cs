using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class MealPreparationTraceTests
{
    [Fact]
    public void Saving_unchanged_menu_preserves_graph_demo_trace_through_json_roundtrip()
    {
        var preparation = Preparation();

        var saved = NutritionJson.Read<MealPayload>(NutritionJson.Write(
            preparation.Complete(preparation.Previous!.Meals)));

        Assert.Equal(NutritionJson.Write(preparation.Previous.RecommendationTrace),
            NutritionJson.Write(saved.RecommendationTrace));
        Assert.Contains("independent_clinical_review_not_claimed", saved.RecommendationTrace!.Warnings);
    }

    [Fact]
    public void Manual_replacement_keeps_demo_disclosure_and_removes_prior_ai_attribution()
    {
        var preparation = Preparation();
        var changed = preparation.Previous!.Meals.Select(meal => meal.MealType == "lunch"
            ? meal with { VersionId = Guid.NewGuid(), Name = "Món thay thế" } : meal).ToArray();

        var replaced = NutritionJson.Read<MealPayload>(NutritionJson.Write(preparation.Complete(changed)));

        var trace = Assert.IsType<MealRecommendationTrace>(replaced.RecommendationTrace);
        Assert.Equal("rule_manual_replacement", trace.Strategy);
        Assert.False(trace.UsedAi);
        Assert.Null(trace.Model);
        Assert.Null(trace.PromptVersion);
        Assert.Null(trace.GroundingRevision);
        Assert.Equal(MealGroundingOptions.OwnerAuthorizedGraphDemoMode, trace.GroundingStrategy);
        Assert.Empty(trace.Evidence);
        Assert.Empty(trace.Explanations);
        Assert.Contains("academic_demo_owner_authorized", trace.Warnings);
        Assert.Contains("meal_replaced_by_user", trace.Warnings);
        Assert.True(preparation.Previous.RecommendationTrace!.UsedAi);
    }

    private static MealPreparation Preparation()
    {
        var snapshot = EligibilityTests.Healthy();
        var meals = new[] { EligibilityTests.Recipe("breakfast", 10), EligibilityTests.Recipe("lunch", 10), EligibilityTests.Recipe("dinner", 10) };
        var date = new DateOnly(2026, 10, 28);
        var assessmentId = Guid.NewGuid();
        var eligibility = NutritionDecision.Create("eligible", []);
        var previous = new MealPayload(1, assessmentId, date, meals, [], NutritionDecision.Create("suggested", []), 8)
        {
            RecommendationTrace = new(1, "graph_grounded_ai_ranked", true, "gemini-fixture", "ranker-v1",
                [new("chunk-1", "Fixture", null, "34", "pdf-page:35", "Fixture, trang 34")],
                [new(meals[1].VersionId, "Giải thích cho món cũ", ["chunk-1"])],
                ["academic_demo_owner_authorized", "independent_clinical_review_not_claimed"],
                "freeze-demo", MealGroundingOptions.OwnerAuthorizedGraphDemoMode)
        };
        return new(assessmentId, date, new(1, snapshot, [], eligibility), previous, meals, [], [], eligibility,
            8, HealthSnapshotNormalizer.Normalize(snapshot, []));
    }
}
