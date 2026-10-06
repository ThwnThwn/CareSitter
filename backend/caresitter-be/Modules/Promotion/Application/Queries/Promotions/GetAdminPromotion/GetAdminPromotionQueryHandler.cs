using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class GetAdminPromotionQueryHandler(IPromotionAdminStore store)
    : IRequestHandler<GetAdminPromotionQuery, AdminPromotionResponse?>
{
    public Task<AdminPromotionResponse?> Handle(GetAdminPromotionQuery request, CancellationToken ct) =>
        store.GetAsync(request.Id, ct);
}
