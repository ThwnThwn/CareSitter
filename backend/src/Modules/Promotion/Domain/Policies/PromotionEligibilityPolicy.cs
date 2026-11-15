using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Domain.Policies;

/// <summary>Pure rules evaluated in order; the adapter supplies history/counts under its DB lock.</summary>
internal static class PromotionEligibilityPolicy
{
    internal static Result CheckApplicability(Domain.Promotion promotion,
        Guid serviceTypeId, DateTimeOffset now)
    {
        if (!promotion.IsAvailableAt(now)) return PromotionErrors.NotActive();
        return promotion.AppliesToService(serviceTypeId)
            ? Result.Success() : PromotionErrors.ServiceNotEligible();
    }

    internal static Result CheckCustomerHistory(Domain.Promotion promotion, bool hasPaidBooking) =>
        promotion.FirstPaidBookingOnly && hasPaidBooking
            ? PromotionErrors.FirstBookingOnly() : Result.Success();

    internal static Result CheckTotalUsage(Domain.Promotion promotion, int activeUsageCount) =>
        promotion.TotalUsageLimit is { } limit && activeUsageCount >= limit
            ? PromotionErrors.UsageLimitReached() : Result.Success();

    internal static Result<long> CalculateDiscount(Domain.Promotion promotion,
        long grossAmount, int customerUsageCount) =>
        customerUsageCount >= promotion.PerCustomerUsageLimit
            ? PromotionErrors.CustomerUsageLimitReached() : promotion.CalculateDiscount(grossAmount);

    internal static Result CheckReservationBinding(PromotionRedemption existing,
        Guid promotionId, Guid customerId) =>
        existing.PromotionId != promotionId || existing.CustomerId != customerId
            ? PromotionErrors.InvalidReservation() : Result.Success();
}
