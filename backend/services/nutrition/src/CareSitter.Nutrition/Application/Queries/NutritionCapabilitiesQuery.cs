using MediatR;

namespace CareSitter.Nutrition.Application;

public sealed record NutritionCapabilitiesQuery : IRequest<NutritionCapabilitiesResponse>;
