using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Configuration;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionFeatures(IConfiguration configuration) : INutritionFeatures
{
    public bool Enabled => configuration.GetValue<bool>("Nutrition:Enabled");
    public bool AssessmentsEnabled => Enabled && configuration.GetValue<bool>("Nutrition:AssessmentsEnabled");
    public bool RecommendationsEnabled => AssessmentsEnabled && configuration.GetValue<bool>("Nutrition:RecommendationsEnabled");
}
