using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

public sealed record NutritionResourceQuery(string Kind, Guid BeneficiaryId, Guid ResourceId) : IRequest<Result<ResourceResponse>>;
