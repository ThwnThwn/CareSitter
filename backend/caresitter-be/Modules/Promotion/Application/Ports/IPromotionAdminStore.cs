using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Application;

public interface IPromotionAdminStore
{
    Task<AdminPromotionPage> ListAsync(string? search, string? status, int page, int pageSize, CancellationToken ct);
    Task<AdminPromotionResponse?> GetAsync(Guid id, CancellationToken ct);
    Task<Result<AdminPromotionChange>> CreateAsync(PromotionConfiguration configuration, CancellationToken ct);
    Task<Result<AdminPromotionChange>> UpdateAsync(Guid id, PromotionConfiguration configuration, DateTimeOffset expectedUpdatedAt, CancellationToken ct);
    Task<Result<AdminPromotionChange>> SetActiveAsync(Guid id, bool isActive, DateTimeOffset expectedUpdatedAt, CancellationToken ct);
    Task<Result<AdminPromotionChange>> DeleteAsync(Guid id, DateTimeOffset expectedUpdatedAt, CancellationToken ct);
}
