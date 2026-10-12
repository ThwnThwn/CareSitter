namespace CareSitter.Nutrition.Application;

public interface INutritionFeatures
{
    bool Enabled { get; }
    bool AssessmentsEnabled { get; }
    bool RecommendationsEnabled { get; }
}
