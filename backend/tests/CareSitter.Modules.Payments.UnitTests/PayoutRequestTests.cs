using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PayoutRequestTests
{
    [Theory]
    [InlineData(-1)]
    [InlineData(0)]
    [InlineData(99_999)]
    public void Create_RejectsAmountBelowMinimum(long amount)
    {
        var result = CreatePayout(amount);

        Assert.True(result.IsFailure);
        Assert.Equal("payout.amount", result.Error.Code);
    }

    [Fact]
    public void Create_AcceptsMinimumAmount()
    {
        var result = CreatePayout(100_000);

        Assert.True(result.IsSuccess);
        Assert.Equal(100_000, result.Value.Amount);
        Assert.Equal("PENDING", result.Value.Status);
    }

    private static CareSitter.SharedKernel.Results.Result<PayoutRequest> CreatePayout(long amount) =>
        PayoutRequest.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid().ToString("N"),
            amount,
            "VCB",
            "NGUYEN VAN A",
            "encrypted-account-number");
}
