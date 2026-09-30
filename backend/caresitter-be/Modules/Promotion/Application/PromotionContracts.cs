using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record PromotionResponse(
    Guid Id,
    string Code,
    string Title,
    string Summary,
    string? Description,
    string BadgeText,
    string DiscountType,
    long DiscountValue,
    long? MaxDiscountAmount,
    long MinOrderAmount,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    bool FirstPaidBookingOnly,
    int PerCustomerUsageLimit,
    bool IsFeatured,
    IReadOnlyList<Guid> EligibleServiceIds,
    IReadOnlyList<string> Terms);

public sealed record PromotionPreviewResponse(
    Guid PromotionId,
    string Code,
    string Title,
    long GrossAmount,
    long DiscountAmount,
    long CustomerPayableAmount,
    long PlatformSubsidyAmount);

public sealed record ListActivePromotionsQuery : IRequest<IReadOnlyList<PromotionResponse>>;
public sealed record GetActivePromotionQuery(Guid PromotionId) : IRequest<PromotionResponse?>;
public sealed record PreviewPromotionCommand(
    string Code,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<PromotionPreviewResponse>>;

internal interface IPromotionReadStore
{
    Task<IReadOnlyList<PromotionResponse>> ListActiveAsync(
        DateTimeOffset now, CancellationToken ct);
    Task<PromotionResponse?> GetActiveAsync(
        Guid id, DateTimeOffset now, CancellationToken ct);
}
