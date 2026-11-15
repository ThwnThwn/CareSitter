namespace CareSitter.Modules.Promotion.Application;

public sealed record AdminPromotionResponse(
    Guid Id, string Code, string Title, string Summary, string? Description, string BadgeText,
    IReadOnlyList<string> Terms, string DiscountType, long DiscountValue, long? MaxDiscountAmount,
    long MinOrderAmount, DateTimeOffset StartsAt, DateTimeOffset EndsAt, bool IsActive,
    bool FirstPaidBookingOnly, int? TotalUsageLimit, int PerCustomerUsageLimit, int Priority,
    bool IsFeatured, IReadOnlyList<Guid> EligibleServiceIds, string Status,
    int ReservedCount, int RedeemedCount, int ReleasedCount, bool HasHistory, bool CanDelete,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
