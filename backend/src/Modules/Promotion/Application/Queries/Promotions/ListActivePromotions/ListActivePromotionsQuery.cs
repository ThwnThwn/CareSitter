using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record ListActivePromotionsQuery : IRequest<IReadOnlyList<PromotionResponse>>;
