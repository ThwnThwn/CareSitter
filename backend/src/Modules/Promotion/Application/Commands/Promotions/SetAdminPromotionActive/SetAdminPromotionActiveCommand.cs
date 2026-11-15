using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record SetAdminPromotionActiveCommand(Guid Id, bool IsActive, DateTimeOffset ExpectedUpdatedAt) : IRequest<Result<AdminPromotionResponse>>;
