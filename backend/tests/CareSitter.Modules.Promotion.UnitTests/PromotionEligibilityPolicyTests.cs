using CareSitter.Modules.Promotion.Domain.Policies;
using CareSitter.Modules.Promotion.Domain;

namespace CareSitter.Modules.Promotion.UnitTests;

public sealed class PromotionEligibilityPolicyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-10-04T00:00:00Z");
    private static Domain.Promotion Promotion() => Domain.Promotion.Create(
        "care10", "Title", "Summary", "Badge", PromotionDiscountType.Percentage,
        10, 100_000, Now, Now.AddHours(1)).Value;
    private static void Configure(Domain.Promotion promotion, string property, object value) =>
        typeof(Domain.Promotion).GetProperty(property)!.SetValue(promotion, value);

    [Fact]
    public void Availability_boundaries_are_inclusive()
    {
        var promotion = Promotion();
        Assert.True(PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now).IsSuccess);
        Assert.True(PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now.AddHours(1)).IsSuccess);
        Assert.Equal("promotion.not_active",
            PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now.AddTicks(-1)).Error.Code);
        Assert.Equal("promotion.not_active",
            PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now.AddHours(1).AddTicks(1)).Error.Code);
    }

    [Fact]
    public void First_paid_booking_rule_does_not_block_general_promotions()
    {
        var promotion = Promotion();
        Assert.True(PromotionEligibilityPolicy.CheckCustomerHistory(promotion, true).IsSuccess);
        Configure(promotion, nameof(promotion.FirstPaidBookingOnly), true);
        Assert.True(PromotionEligibilityPolicy.CheckCustomerHistory(promotion, false).IsSuccess);
        Assert.Equal("promotion.first_booking_only",
            PromotionEligibilityPolicy.CheckCustomerHistory(promotion, true).Error.Code);
    }

    [Fact]
    public void Service_scope_rejects_other_services_after_availability_check()
    {
        var promotion = Promotion();
        var serviceId = Guid.NewGuid();
        var scope = (PromotionServiceScope)Activator.CreateInstance(typeof(PromotionServiceScope), true)!;
        typeof(PromotionServiceScope).GetProperty(nameof(scope.PromotionId))!.SetValue(scope, promotion.Id);
        typeof(PromotionServiceScope).GetProperty(nameof(scope.ServiceTypeId))!.SetValue(scope, serviceId);
        ((ICollection<PromotionServiceScope>)promotion.ServiceScopes).Add(scope);
        Assert.True(PromotionEligibilityPolicy.CheckApplicability(promotion, serviceId, Now).IsSuccess);
        Assert.Equal("promotion.service_not_eligible",
            PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now).Error.Code);
        Assert.Equal("promotion.not_active",
            PromotionEligibilityPolicy.CheckApplicability(promotion, Guid.NewGuid(), Now.AddTicks(-1)).Error.Code);
    }

    [Fact]
    public void Total_and_customer_quotas_reject_at_exact_limit()
    {
        var promotion = Promotion();
        Assert.True(PromotionEligibilityPolicy.CheckTotalUsage(promotion, 100).IsSuccess);
        Configure(promotion, nameof(promotion.TotalUsageLimit), 2);
        Assert.True(PromotionEligibilityPolicy.CheckTotalUsage(promotion, 1).IsSuccess);
        Assert.Equal("promotion.usage_limit_reached",
            PromotionEligibilityPolicy.CheckTotalUsage(promotion, 2).Error.Code);
        Assert.Equal(10_000, PromotionEligibilityPolicy.CalculateDiscount(promotion, 100_000, 0).Value);
        Assert.Equal("promotion.customer_usage_limit_reached",
            PromotionEligibilityPolicy.CalculateDiscount(promotion, 100_000, 1).Error.Code);
        // Quota is checked before gross/minimum, matching the existing API error priority.
        Assert.Equal("promotion.customer_usage_limit_reached",
            PromotionEligibilityPolicy.CalculateDiscount(promotion, 0, 1).Error.Code);
    }

    [Fact]
    public void Reservation_cannot_be_reused_by_another_customer_or_promotion()
    {
        var promotion = Promotion();
        var customer = Guid.NewGuid();
        var reservation = PromotionRedemption.Reserve(promotion.Id, customer, Guid.NewGuid(),
            10_000, Now, Now.AddMinutes(15)).Value;
        Assert.True(PromotionEligibilityPolicy.CheckReservationBinding(reservation, promotion.Id, customer).IsSuccess);
        Assert.Equal("promotion.invalid_reservation",
            PromotionEligibilityPolicy.CheckReservationBinding(reservation, promotion.Id, Guid.NewGuid()).Error.Code);
        Assert.Equal("promotion.invalid_reservation",
            PromotionEligibilityPolicy.CheckReservationBinding(reservation, Guid.NewGuid(), customer).Error.Code);
    }
}
