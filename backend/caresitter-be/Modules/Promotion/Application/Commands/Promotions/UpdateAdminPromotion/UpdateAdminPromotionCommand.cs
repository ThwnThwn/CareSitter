using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record UpdateAdminPromotionCommand(Guid Id, PromotionConfiguration Configuration, DateTimeOffset ExpectedUpdatedAt) : IRequest<Result<AdminPromotionResponse>>;
