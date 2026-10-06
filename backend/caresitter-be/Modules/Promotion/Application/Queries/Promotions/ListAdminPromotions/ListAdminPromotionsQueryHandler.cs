using MediatR;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class ListAdminPromotionsQueryHandler(IPromotionAdminStore store)
    : IRequestHandler<ListAdminPromotionsQuery, Result<AdminPromotionPage>>
{
    public async Task<Result<AdminPromotionPage>> Handle(ListAdminPromotionsQuery request, CancellationToken ct) =>
        await store.ListAsync(request.Search, request.Status, request.Page, request.PageSize, ct);
}
