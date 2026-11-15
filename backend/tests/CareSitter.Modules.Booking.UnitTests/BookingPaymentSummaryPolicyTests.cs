using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingPaymentSummaryPolicyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-11-14T02:00:00Z");
    private static Domain.Booking Pending()
    {
        var booking = Domain.Booking.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), Now.AddHours(2), Now.AddHours(4), paymentDeadline: Now.AddMinutes(30)).Value;
        booking.ApplyPricing(100_000, 15_000, 85_000, disputeWindowHours: 48);
        booking.ApplyPromotion(Guid.NewGuid(), "TEST", 100_000, 20_000, 80_000, 20_000);
        booking.TransitionTo(BookingStatus.PendingPayment);
        return booking;
    }
    [Fact]
    public void Amount_due_uses_server_payable_and_expires_at_payment_deadline()
    {
        var booking = Pending();
        var summary = BookingPaymentSummaryPolicy.Describe(booking, Now);
        Assert.Equal(80_000, summary.AmountDue);
        Assert.True(summary.CanPay);
        Assert.Equal(0, summary.RefundIfCancelledNow);
        Assert.Equal(80_000, summary.RefundAfterPaymentIfCancelledNow);
        Assert.Equal(BookingStatus.PendingPayment, booking.Status);
        Assert.Null(BookingPaymentSummaryPolicy.Describe(booking, booking.PaymentDeadline).RefundAfterPaymentIfCancelledNow);
        Assert.False(BookingPaymentSummaryPolicy.Describe(booking, booking.PaymentDeadline).CanPay);
    }

    [Fact]
    public void After_payment_preview_matches_actual_policy_without_marking_the_booking_paid()
    {
        var booking = Pending();
        var projected = BookingCancellationPolicy.PreviewAfterPayment(booking, Now);
        Assert.Equal(0, BookingCancellationPolicy.Evaluate(booking, Now).Value.RefundAmount);
        booking.ConfirmPayment();
        Assert.Equal(BookingCancellationPolicy.Evaluate(booking, Now).Value.RefundAmount, projected.Value.RefundAmount);
    }
    [Fact]
    public void Paid_cancellation_preview_uses_same_policy_as_cancel_command()
    {
        var booking = Pending();
        booking.ConfirmPayment();
        var summary = BookingPaymentSummaryPolicy.Describe(booking, Now);
        Assert.False(summary.CanPay);
        Assert.Equal(0, summary.AmountDue);
        Assert.Equal(BookingCancellationPolicy.Evaluate(booking, Now).Value.RefundAmount,
            summary.RefundIfCancelledNow);
        Assert.Equal(80_000, summary.RefundIfCancelledNow);
        Assert.Null(summary.SettlementEligibleAt);
        Assert.Contains("48", summary.SettlementExplanation);
    }
    [Fact]
    public void Reconciliation_never_claims_no_refund_or_invites_another_payment()
    {
        var booking = Pending();
        booking.BeginPaymentReconciliation();
        var summary = BookingPaymentSummaryPolicy.Describe(booking, Now);
        Assert.False(summary.CanPay);
        Assert.True(summary.CanCancel);
        Assert.Null(summary.RefundIfCancelledNow);
        Assert.Contains("đối soát", summary.PaymentExplanation);
    }
    [Fact]
    public void Assigned_caregiver_after_start_requires_dispute_instead_of_refund_promise()
    {
        var booking = Pending();
        booking.ConfirmPayment();
        var caregiver = Guid.NewGuid();
        booking.SelectCaregiver(caregiver);
        booking.AssignCaregiver(caregiver);
        var summary = BookingPaymentSummaryPolicy.Describe(booking, booking.ScheduledStart);
        Assert.True(summary.RequiresDispute);
        Assert.False(summary.CanCancel);
        Assert.Null(summary.RefundIfCancelledNow);
    }
    [Fact]
    public void Unmatched_paid_booking_remains_refundable_after_start()
    {
        var booking = Pending();
        booking.ConfirmPayment();
        booking.MarkMatchingFailed();
        var summary = BookingPaymentSummaryPolicy.Describe(booking, booking.ScheduledEnd);
        Assert.True(summary.CanCancel);
        Assert.Equal(80_000, summary.RefundIfCancelledNow);
    }
}
