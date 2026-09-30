using CareSitter.Modules.Promotion.Domain;

namespace CareSitter.Modules.Promotion.UnitTests;

public sealed class PromotionDomainTests
{
    [Fact]
    public void Percentage_discount_is_capped_and_never_changes_gross_price()
    {
        var promotion = Domain.Promotion.Create("welcome20", "Khách mới", "Giảm 20%",
            "Giảm 20%", PromotionDiscountType.Percentage, 20, 100_000,
            DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1),
            maxDiscountAmount: 100_000).Value;

        var result = promotion.CalculateDiscount(800_000);

        Assert.True(result.IsSuccess);
        Assert.Equal(100_000, result.Value);
    }

    [Fact]
    public void Discount_rejects_orders_below_the_minimum()
    {
        var promotion = Domain.Promotion.Create("care50", "Ưu đãi", "Giảm 50k",
            "Giảm 50k", PromotionDiscountType.FixedAmount, 50_000, 300_000,
            DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1)).Value;

        var result = promotion.CalculateDiscount(250_000);

        Assert.True(result.IsFailure);
        Assert.Equal("promotion.minimum_order_not_met", result.Error.Code);
    }

    [Fact]
    public void Reservation_lifecycle_is_idempotent()
    {
        var now = DateTimeOffset.UtcNow;
        var reservation = PromotionRedemption.Reserve(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), 50_000, now, now.AddMinutes(30)).Value;

        Assert.True(reservation.Redeem(now.AddMinutes(1)).IsSuccess);
        Assert.True(reservation.Redeem(now.AddMinutes(2)).IsSuccess);
        Assert.Equal(PromotionRedemptionStatus.Redeemed, reservation.Status);
        Assert.True(reservation.Release(now.AddMinutes(3), "CANCELLED").IsFailure);
    }

    [Fact]
    public void Discount_never_creates_a_zero_value_payment()
    {
        var promotion = Domain.Promotion.Create("free", "Ưu đãi", "Giảm toàn bộ",
            "Giảm 100%", PromotionDiscountType.Percentage, 100, 0,
            DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1)).Value;

        var result = promotion.CalculateDiscount(100_000);

        Assert.True(result.IsFailure);
        Assert.Equal("promotion.zero_payment_not_supported", result.Error.Code);
    }
}
