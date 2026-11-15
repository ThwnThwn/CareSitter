namespace CareSitter.Nutrition.Application;

public sealed record NutritionCapabilitiesResponse(bool Enabled, bool AssessmentsEnabled, bool RecommendationsEnabled,
    bool FreeTextParserReady)
{
    public string Disclaimer { get; init; } = NutritionDisclaimer.Reference;
    public string DisclaimerVersion { get; init; } = NutritionDisclaimer.ReferenceVersion;
}
