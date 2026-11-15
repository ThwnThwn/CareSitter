using CareSitter.Modules.Promotion.Domain;

namespace CareSitter.Modules.Promotion.Controllers;

internal static class AdminPromotionRequestMapper
{
    public static PromotionConfiguration ToConfiguration(this UpsertAdminPromotionRequest request) => new(
        request.Code, request.Title, request.Summary, request.Description, request.BadgeText,
        request.Terms, request.DiscountType switch
        {
            "percentage" => PromotionDiscountType.Percentage,
            "fixed_amount" => PromotionDiscountType.FixedAmount,
            _ => (PromotionDiscountType)(-1)
        },
        request.DiscountValue, request.MaxDiscountAmount, request.MinOrderAmount,
        request.StartsAt, request.EndsAt, request.IsActive, request.FirstPaidBookingOnly,
        request.TotalUsageLimit, request.PerCustomerUsageLimit, request.Priority,
        request.IsFeatured, request.EligibleServiceIds);
}
