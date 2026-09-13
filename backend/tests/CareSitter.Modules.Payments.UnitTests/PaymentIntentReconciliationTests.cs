using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PaymentIntentReconciliationTests
{
    [Fact]
    public void ReconciliationAttempt_TracksScheduleAndFailureSource()
    {
        var intent = CreatePendingIntent();
        var attemptedAt = DateTimeOffset.UtcNow;
        var nextAttemptAt = attemptedAt.AddMinutes(3);

        var recorded = intent.RecordReconciliationAttempt(
            attemptedAt, nextAttemptAt, "VNPay is still processing");
        var failed = intent.MarkFailed("{}", "ReconciliationJob");

        Assert.True(recorded.IsSuccess);
        Assert.True(failed.IsSuccess);
        Assert.Equal(1, intent.ReconciliationAttempts);
        Assert.Equal(attemptedAt, intent.ReconciliationStartedAt);
        Assert.Equal(attemptedAt, intent.LastReconciliationAt);
        Assert.Null(intent.NextReconciliationAt);
        Assert.Equal("VNPay is still processing", intent.LastReconciliationError);
        Assert.Equal("ReconciliationJob", intent.FinalizedSource);
        Assert.Equal("FAILED", intent.Status);
    }

    [Fact]
    public void PendingIntent_CanBeSupersededIdempotently()
    {
        var intent = CreatePendingIntent();

        Assert.True(intent.MarkSuperseded().IsSuccess);
        Assert.True(intent.MarkSuperseded().IsSuccess);
        Assert.Equal("SUPERSEDED", intent.Status);
    }

    private static PaymentIntent CreatePendingIntent()
    {
        var intent = PaymentIntent.Create(
            Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 100_000, Guid.NewGuid().ToString("N")).Value;
        Assert.True(intent.MarkPending().IsSuccess);
        return intent;
    }
}
