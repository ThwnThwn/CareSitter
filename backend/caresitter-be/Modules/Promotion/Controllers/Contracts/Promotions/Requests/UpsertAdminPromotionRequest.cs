namespace CareSitter.Modules.Promotion.Controllers;

public sealed record UpsertAdminPromotionRequest(
    string Code, string Title, string Summary, string? Description, string BadgeText,
    IReadOnlyList<string> Terms, string DiscountType, long DiscountValue, long? MaxDiscountAmount,
    long MinOrderAmount, DateTimeOffset StartsAt, DateTimeOffset EndsAt, bool IsActive,
    bool FirstPaidBookingOnly, int? TotalUsageLimit, int PerCustomerUsageLimit, int Priority,
    bool IsFeatured, IReadOnlyList<Guid> EligibleServiceIds, DateTimeOffset? ExpectedUpdatedAt = null);
