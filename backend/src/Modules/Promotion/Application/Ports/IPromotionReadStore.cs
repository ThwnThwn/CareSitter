using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal interface IPromotionReadStore
{
    Task<IReadOnlyList<PromotionResponse>> ListActiveAsync(
        DateTimeOffset now, CancellationToken ct);
    Task<PromotionResponse?> GetActiveAsync(
        Guid id, DateTimeOffset now, CancellationToken ct);
}
