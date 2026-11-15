using CareSitter.SharedKernel.Results;

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
