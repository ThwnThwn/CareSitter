using System.Text.Json.Serialization;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public interface IMealRecommendationEngine
{
    Task<MealRecommendationResult> RecommendAsync(MealRecommendationRequest request, CancellationToken ct);
}

public sealed record MealRecommendationRequest(long CatalogRevision, Recipe[] CandidateRecipes,
    IReadOnlyList<HealthFact> Facts, IReadOnlyList<DietaryRule> Rules,
    string DietaryPattern, string NutritionGoal, Recipe[]? RecentMeals = null,
    Recipe[][]? PreviousMenus = null, MealPreferences? Preferences = null,
    Recipe[]? YesterdayMeals = null, string? VarietySeed = null);

public sealed record MealPreferences(string MealFormatPreference, string[] PreferredFoods,
    string[] DislikedFoods)
{
    public static MealPreferences FromEvidence(IReadOnlyDictionary<string, string> evidence) => new(
        evidence.GetValueOrDefault("mealFormatPreference", "no_preference"),
        Split(evidence.GetValueOrDefault("preferredFoods", string.Empty)),
        Split(evidence.GetValueOrDefault("dislikedFoods", string.Empty)));

    private static string[] Split(string value) => value
        .Split([';', ',', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .Take(20)
        .ToArray();
}

public sealed record MealRecommendationResult(Recipe[]? Meals, MealRecommendationTrace Trace);

public sealed record MealRecommendationTrace(int SchemaVersion, string Strategy, bool UsedAi,
    string? Model, string? PromptVersion, MealRecommendationEvidence[] Evidence,
    MealRecommendationExplanation[] Explanations, string[] Warnings,
    string? GroundingRevision = null, string? GroundingStrategy = null, string ReleaseStatus = "demo")
{
    public string? RetrievalStrategy { get; init; }
    public string GraphRole { get; init; } = "none";
    public string CitationScope { get; init; } = "metadata_only";
    public MealCitation[] Citations { get; init; } = [];
    public MealVerifiedReason[] VerifiedReasons { get; init; } = [];
    public string Disclaimer { get; init; } = NutritionDisclaimer.Reference;
    public string DisclaimerVersion { get; init; } = NutritionDisclaimer.ReferenceVersion;
}

public sealed record MealVerifiedReason(Guid RecipeVersionId, string Code, string Detail)
{
    public string? SourceField { get; init; }
    public Guid? RuleVersionId { get; init; }
    public string[] SourceIds { get; init; } = [];
}

public sealed record MealCitation(string Title, string? Chapter, string? Heading, string? Pages,
    MealGraphStep[] GraphPath);
public sealed record MealGraphStep(string NodeId, string? Heading, int[] Pages);

public sealed record MealRecommendationEvidence(string Id, string Title, string? Chapter,
    string? PrintedPages, string Locator, string Reference,
    [property: JsonIgnore] string? Excerpt = null)
{
    public string? SourceTitle { get; init; }
    public MealGraphStep[] GraphPath { get; init; } = [];
}

public sealed record MealRecommendationExplanation(Guid RecipeVersionId, string Summary,
    string[] EvidenceIds);
