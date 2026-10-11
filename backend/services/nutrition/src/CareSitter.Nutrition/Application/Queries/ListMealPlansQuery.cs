using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

public sealed record ListMealPlansQuery(Guid BeneficiaryId) : IRequest<Result<IReadOnlyList<ResourceResponse>>>;
