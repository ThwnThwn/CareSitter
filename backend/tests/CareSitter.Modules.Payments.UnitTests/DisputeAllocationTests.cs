using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class DisputeAllocationTests
{
    [Theory]
    [InlineData("CUSTOMER_WINS", null, 0, 100000, 0, 0, 0)]
    [InlineData("CAREGIVER_WINS", null, 5000, 0, 15000, 0, 85000)]
    [InlineData("PARTIAL_REFUND", 40000L, 5000, 40000, 9000, 5000, 46000)]
    [InlineData(" partial_refund ", 90000L, 0, 90000, 1500, 0, 8500)]
    public void Splits_only_the_locked_escrow(string decision, long? refund, long penalty,
        long expectedRefund, long expectedFee, long expectedPenalty, long expectedEarning)
    {
        var result = DisputeAllocation.Create(
            100000, 100000, 0, 15000, decision, refund, penalty);
        Assert.True(result.IsSuccess);
        var value = result.Value;
        Assert.Equal(expectedRefund, value.CustomerRefund);
        Assert.Equal(0, value.PromotionReversal);
        Assert.Equal(expectedFee, value.Fee);
        Assert.Equal(expectedPenalty, value.Penalty);
        Assert.Equal(expectedEarning, value.CaregiverEarning);
        Assert.Equal(100000, value.CustomerRefund + value.PromotionReversal +
            value.Fee + value.Penalty + value.CaregiverEarning);
    }

    [Theory]
    [InlineData("PARTIAL_REFUND", null, 0)]
    [InlineData("PARTIAL_REFUND", 100000L, 0)]
    [InlineData("PARTIAL_REFUND", 90000L, 9000)]
    [InlineData("CUSTOMER_WINS", null, -1)]
    [InlineData("UNKNOWN", null, 0)]
    public void Rejects_invalid_outcomes_before_any_persistence(string decision, long? refund, long penalty)
    {
        Assert.True(DisputeAllocation.Create(
            100000, 100000, 0, 15000, decision, refund, penalty).IsFailure);
    }

    [Fact]
    public void Partial_refund_reverses_promotion_and_platform_fee_pro_rata()
    {
        var result = DisputeAllocation.Create(
            escrowAmount: 100000,
            customerPayableAmount: 80000,
            promotionSubsidyAmount: 20000,
            platformFeeAmount: 15000,
            decision: "PARTIAL_REFUND",
            refundAmount: 40000,
            caregiverPenaltyAmount: 0);

        Assert.True(result.IsSuccess);
        Assert.Equal(40000, result.Value.CustomerRefund);
        Assert.Equal(10000, result.Value.PromotionReversal);
        Assert.Equal(7500, result.Value.Fee);
        Assert.Equal(42500, result.Value.CaregiverEarning);
    }
}
