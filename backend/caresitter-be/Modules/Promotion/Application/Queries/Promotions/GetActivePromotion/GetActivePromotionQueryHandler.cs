using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class GetActivePromotionQueryHandler(IPromotionReadStore store, IClock clock)
    : IRequestHandler<GetActivePromotionQuery, PromotionResponse?>
{
    public Task<PromotionResponse?> Handle(GetActivePromotionQuery request, CancellationToken ct) =>
        store.GetActiveAsync(request.PromotionId, clock.UtcNow, ct);
}
