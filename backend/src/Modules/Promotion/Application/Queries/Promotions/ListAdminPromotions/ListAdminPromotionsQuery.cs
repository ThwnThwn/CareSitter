using MediatR;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Application;

public sealed record ListAdminPromotionsQuery(string? Search = null, string? Status = null,
    int Page = 1, int PageSize = 20) : IRequest<Result<AdminPromotionPage>>;
