using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record GetAdminPromotionQuery(Guid Id) : IRequest<AdminPromotionResponse?>;
