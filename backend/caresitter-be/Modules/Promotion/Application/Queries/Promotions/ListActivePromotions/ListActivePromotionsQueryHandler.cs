using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class ListActivePromotionsQueryHandler(IPromotionReadStore store, IClock clock)
    : IRequestHandler<ListActivePromotionsQuery, IReadOnlyList<PromotionResponse>>
{
    public Task<IReadOnlyList<PromotionResponse>> Handle(
        ListActivePromotionsQuery request, CancellationToken ct) =>
        store.ListActiveAsync(clock.UtcNow, ct);
}
