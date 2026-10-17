using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class RefundRequestTests
{
    [Fact]
    public void PayOSRefund_RequiresManualEvidenceBeforeSuccess()
    {
        var request = RefundRequest.Create(
            SucceededIntent("PAYOS"),
            "BOOKING_CANCELLED",
            DateTimeOffset.UtcNow,
            canProcessAutomatically: false).Value;

        Assert.Equal("MANUAL_REQUIRED", request.Status);
        Assert.True(request.ConfirmManual(Guid.NewGuid(), "", "merchant evidence", DateTimeOffset.UtcNow).IsFailure);
        Assert.True(request.ConfirmManual(Guid.NewGuid(), "refund-001", "", DateTimeOffset.UtcNow).IsFailure);

        var adminId = Guid.NewGuid();
        var completedAt = DateTimeOffset.UtcNow;
        var confirmed = request.ConfirmManual(
            adminId, " refund-001 ", " checked merchant portal ", completedAt);

        Assert.True(confirmed.IsSuccess);
        Assert.Equal("SUCCEEDED", request.Status);
        Assert.Equal("refund-001", request.ProviderRefundId);
        Assert.Equal("CONFIRMED_MANUALLY", request.ProviderTransactionStatus);
        Assert.Equal(adminId, request.ConfirmedByAdminId);
        Assert.Equal("checked merchant portal", request.AdminConfirmationNote);
        Assert.Equal(completedAt, request.CompletedAt);
    }

    [Fact]
    public void AmbiguousAutomaticRefund_CanOnlyContinueWithANewLease()
    {
        var now = DateTimeOffset.UtcNow;
        var request = RefundRequest.Create(
            SucceededIntent("VNPAY"),
            "NO_CAREGIVER_AVAILABLE",
            now,
            canProcessAutomatically: true).Value;
        var firstLease = Guid.NewGuid();

        Assert.Equal("PENDING", request.Status);
        Assert.True(request.BeginProviderAttempt(
            firstLease, now, now.AddSeconds(30), now.AddSeconds(10)).IsSuccess);
        Assert.Equal(1, request.AttemptCount);
        Assert.True(request.RecordProviderProgress(
            firstLease,
            "UNKNOWN",
            "response-001",
            null,
            null,
            "TIMEOUT",
            now.AddSeconds(10),
            now.AddSeconds(1)).IsSuccess);
        Assert.Equal("UNKNOWN", request.Status);

        var secondLease = Guid.NewGuid();
        Assert.True(request.BeginProviderAttempt(
            secondLease, now.AddSeconds(10), now.AddSeconds(40), now.AddSeconds(20)).IsSuccess);
        Assert.Equal(2, request.AttemptCount);
        var staleResult = request.RecordProviderProgress(
            firstLease, "SUCCEEDED", null, "refund-stale", "00", null, null, now.AddSeconds(11));
        Assert.True(staleResult.IsFailure);
        Assert.Equal("PROCESSING", request.Status);
    }

    [Fact]
    public void PartialRefund_CannotExceedOriginalPayment()
    {
        var intent = SucceededIntent("VNPAY");

        var partial = RefundRequest.Create(
            intent, 40_000, "DISPUTE_PARTIAL_REFUND", DateTimeOffset.UtcNow,
            canProcessAutomatically: true);
        var excessive = RefundRequest.Create(
            intent, 100_001, "DISPUTE_PARTIAL_REFUND", DateTimeOffset.UtcNow,
            canProcessAutomatically: true);

        Assert.True(partial.IsSuccess);
        Assert.Equal(40_000, partial.Value.Amount);
        Assert.True(excessive.IsFailure);
        Assert.Equal("refund.amount", excessive.Error.Code);
    }

    private static PaymentIntent SucceededIntent(string provider)
    {
        var intent = PaymentIntent.Create(
            Guid.NewGuid(), Guid.NewGuid(), provider, 100_000, Guid.NewGuid().ToString("N")).Value;
        Assert.True(intent.SetProviderOrderRef(provider == "VNPAY" ? "CS123456" : "123456789").IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        Assert.True(intent.MarkSucceeded(
            provider == "VNPAY" ? "987654321" : "payos-link-id",
            finalizedSource: "TEST").IsSuccess);
        return intent;
    }
}
