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
        Assert.Equal("PAYOS", result.Value.Provider);
        Assert.StartsWith("CS", result.Value.ProviderReferenceId);
    }

    [Fact]
    public void ProviderLifecycle_DoesNotBecomePaidBeforeConfirmation()
    {
        var payout = CreatePayout(100_000).Value;
        var now = DateTimeOffset.UtcNow;

        Assert.True(payout.Approve(Guid.NewGuid()).IsSuccess);
        Assert.Equal("APPROVED", payout.Status);
        Assert.True(payout.BeginProviderAttempt(now, now.AddSeconds(15)).IsSuccess);
        Assert.Equal("PROCESSING", payout.Status);
        Assert.True(payout.RecordProviderProgress(
            "provider-id", "PROCESSING:PROCESSING", null, null,
            now, now.AddSeconds(15)).IsSuccess);
        Assert.Equal("PROCESSING", payout.Status);
        Assert.True(payout.MarkPaid(now.AddSeconds(1)).IsSuccess);
        Assert.Equal("PAID", payout.Status);
    }

    [Theory]
    [InlineData("")]
    [InlineData("97043")]
    [InlineData("97043A")]
    public void Create_RejectsInvalidBankBin(string bankBin)
    {
        var result = PayoutRequest.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid().ToString("N"),
            100_000, "VCB", bankBin, "NGUYEN VAN A", "encrypted-account-number");

        Assert.True(result.IsFailure);
        Assert.Equal("payout.bank_bin", result.Error.Code);
    }

    private static CareSitter.SharedKernel.Results.Result<PayoutRequest> CreatePayout(long amount) =>
        PayoutRequest.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid().ToString("N"),
            amount,
            "VCB",
            "970436",
            "NGUYEN VAN A",
            "encrypted-account-number");
}
