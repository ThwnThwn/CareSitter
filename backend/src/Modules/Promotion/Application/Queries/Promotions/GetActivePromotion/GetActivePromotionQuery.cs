using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record GetActivePromotionQuery(Guid PromotionId) : IRequest<PromotionResponse?>;
