using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class NutritionCapabilitiesQueryHandler(INutritionFeatures features, IHealthDescriptionParser parser)
    : IRequestHandler<NutritionCapabilitiesQuery, NutritionCapabilitiesResponse>
{
    public Task<NutritionCapabilitiesResponse> Handle(NutritionCapabilitiesQuery request, CancellationToken ct) =>
        Task.FromResult(new NutritionCapabilitiesResponse(features.Enabled, features.AssessmentsEnabled,
            features.RecommendationsEnabled, parser.IsReady));
}
