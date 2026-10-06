using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record CreateAdminPromotionCommand(PromotionConfiguration Configuration) : IRequest<Result<AdminPromotionResponse>>;
