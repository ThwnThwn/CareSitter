using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

public sealed record ReplacementOptionsQuery(Guid BeneficiaryId, Guid RecommendationId, string MealType)
    : IRequest<Result<IReadOnlyList<Recipe>>>;
