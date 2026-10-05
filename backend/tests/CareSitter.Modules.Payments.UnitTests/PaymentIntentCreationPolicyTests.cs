using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.PaymentIntents;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PaymentIntentCreationPolicyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-10-04T00:00:00Z");
    private static BookingPaymentSnapshot Booking() => new(Guid.NewGuid(), Guid.NewGuid(),
        null, Guid.NewGuid(), Now.AddHours(2), Now.AddHours(4), Now.AddMinutes(15),
        100_000, 80_000, 0, BookingPaymentState.PendingPayment);

    [Fact]
    public void Admission_preserves_status_priority_and_exact_deadline()
    {
        var booking = Booking();
        Assert.Null(PaymentIntentCreationPolicy.CheckBooking(booking, booking.PaymentDeadline.AddTicks(-1)));
        var expired = PaymentIntentCreationPolicy.CheckBooking(booking, booking.PaymentDeadline)!;
        Assert.Equal("BOOKING_PAYMENT_DEADLINE_EXPIRED", expired.Code);
        Assert.Equal(booking.PaymentDeadline, expired.PaymentDeadline);
        Assert.Null(PaymentIntentCreationPolicy.CheckBooking(
            booking with { State = BookingPaymentState.Confirmed }, booking.PaymentDeadline)!.Code);
    }

    [Theory]
    [InlineData(VNPayQueryState.Succeeded, "Finalize", null)]
    [InlineData(VNPayQueryState.Processing, "Block", "PAYMENT_IN_PROGRESS")]
    [InlineData(VNPayQueryState.Unknown, "Block", "PAYMENT_STATUS_UNKNOWN")]
    [InlineData(VNPayQueryState.NotFound, "CloseExpired", null)]
    [InlineData(VNPayQueryState.Failed, "CloseFailed", null)]
    public void Retry_is_decided_without_provider_io(VNPayQueryState state,
        string action, string? code)
    {
        var decision = PaymentIntentCreationPolicy.EvaluateRetry(state, Now, TimeSpan.FromMinutes(15));
        Assert.Equal(action, decision.Action.ToString());
        Assert.Equal(code, decision.Conflict?.Code);
        if (action == "Block")
            Assert.Equal(Now.AddMinutes(15), decision.Conflict!.ExpiresAt);
    }

    [Fact]
    public void Successful_or_uncertain_payments_never_create_another_attempt()
    {
        Assert.Equal("PAYMENT_ALREADY_SUCCEEDED",
            PaymentIntentCreationPolicy.CheckPreviousAttempt("SUCCEEDED")!.Code);
        Assert.Null(PaymentIntentCreationPolicy.CheckPreviousAttempt("FAILED"));
        Assert.Equal("PAYMENT_STATUS_UNKNOWN", PaymentIntentCreationPolicy.QueryUnavailable().Code);
        Assert.Equal("PAYMENT_NEEDS_REVIEW", PaymentIntentCreationPolicy.FinalizationConflict(false).Code);
        Assert.Equal("PAYMENT_ALREADY_SUCCEEDED", PaymentIntentCreationPolicy.FinalizationConflict(true).Code);
        Assert.Equal(PaymentRetryAction.Block,
            PaymentIntentCreationPolicy.EvaluateRetry((VNPayQueryState)999, Now, TimeSpan.Zero).Action);
    }
}
