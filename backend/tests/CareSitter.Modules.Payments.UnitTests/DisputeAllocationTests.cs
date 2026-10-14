using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class DisputeAllocationTests
{
    [Theory]
    [InlineData("CUSTOMER_WINS", null, 0, 100000, 0, 0, 0)]
    [InlineData("CAREGIVER_WINS", null, 5000, 0, 15000, 0, 85000)]
    [InlineData("PARTIAL_REFUND", 40000L, 5000, 40000, 15000, 5000, 40000)]
    [InlineData(" partial_refund ", 90000L, 0, 90000, 10000, 0, 0)]
    public void Splits_only_the_locked_escrow(string decision, long? refund, long penalty,
        long expectedRefund, long expectedFee, long expectedPenalty, long expectedEarning)
    {
        var result = DisputeAllocation.Create(100000, 15000, decision, refund, penalty);
        Assert.True(result.IsSuccess);
        var value = result.Value;
        Assert.Equal(expectedRefund, value.Refund);
        Assert.Equal(expectedFee, value.Fee);
        Assert.Equal(expectedPenalty, value.Penalty);
        Assert.Equal(expectedEarning, value.CaregiverEarning);
        Assert.Equal(100000, value.Refund + value.Fee + value.Penalty + value.CaregiverEarning);
    }

    [Theory]
    [InlineData("PARTIAL_REFUND", null, 0)]
    [InlineData("PARTIAL_REFUND", 100000L, 0)]
    [InlineData("PARTIAL_REFUND", 90000L, 1)]
    [InlineData("CUSTOMER_WINS", null, -1)]
    [InlineData("UNKNOWN", null, 0)]
    public void Rejects_invalid_outcomes_before_any_persistence(string decision, long? refund, long penalty)
    {
        Assert.True(DisputeAllocation.Create(100000, 15000, decision, refund, penalty).IsFailure);
    }
}
