using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Application;

internal sealed class BookingJobsService(BookingCheckoutJobs checkoutJobs, IBookingSettlementStore settlements,
    IBookingJobNotifier notifier, IWalletService wallet, IDisputeLookupService disputes,
    IMatchingService matching, IPaymentReconciliationJob reconciliation, ILogger<BookingJobsService> logger) : IBookingJobsService
{
    public Task ReconcilePendingPaymentsAsync() => reconciliation.ExecuteAsync();

    public Task AlertLateCheckinsAsync() => checkoutJobs.AlertLateCheckinsAsync();
    public Task AutoRequestCheckoutExpiredShiftsAsync() => checkoutJobs.AutoRequestCheckoutExpiredShiftsAsync();
    public Task AutoConfirmPendingCheckoutsAsync() => checkoutJobs.AutoConfirmPendingCheckoutsAsync();

    public async Task ExpandExpiredBookingOffersAsync()
    {
        var expanded = await matching.ExpandExpiredOffersAsync(CancellationToken.None);
        if (expanded > 0) logger.LogInformation("[BookingJobs] Expanded {Count} expired caregiver offers", expanded);
    }

    public async Task RefundUnmatchedBookingsAsync()
    {
        await foreach (var booking in settlements.UnmatchedBookingsAsync())
            await ProcessOriginalPaymentRefundAsync(booking, "NO_CAREGIVER_AVAILABLE");
        await foreach (var booking in settlements.BookingsAwaitingRefundAsync())
            await ProcessOriginalPaymentRefundAsync(booking,
                booking.Status == BookingStatus.Disputed
                    ? "DISPUTE_CUSTOMER_REFUND"
                    : "CUSTOMER_CANCELLATION");
    }

    private async Task ProcessOriginalPaymentRefundAsync(
        CareSitter.Modules.Booking.Domain.Booking booking,
        string reason)
    {
        try
        {
            var amount = booking.RefundAmount ?? booking.CustomerPayableAmount;
            var requested = await wallet.RequestOriginalPaymentRefundAsync(
                booking.Id, booking.CustomerId, amount, reason);
            if (requested.IsFailure)
            {
                logger.LogWarning(
                    "Could not ensure original-payment refund for booking {BookingId}: {ErrorCode}",
                    booking.Id, requested.Error.Code);
                return;
            }

            if (requested.Value.State == OriginalPaymentRefundState.Confirmed)
            {
                var refunded = await settlements.MarkRefundedAsync(booking.Id);
                if (refunded is not null)
                    await notifier.RefundedAsync(refunded, requested.Value);
            }
            else if (requested.Value.State is OriginalPaymentRefundState.Failed or
                     OriginalPaymentRefundState.NotRequired)
                logger.LogWarning(
                    "Refund for booking {BookingId} is {RefundState}; booking remains unchanged.",
                    booking.Id, requested.Value.State);
        }
        catch (Exception error)
        {
            logger.LogError(error, "Failed to reconcile refund for booking {BookingId}", booking.Id);
        }
    }

    public async Task ReleaseMatureSettlementsAsync()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var booking in (await settlements.UnreleasedSettlementsAsync())
            .Where(booking => BookingLifecyclePolicy.IsSettlementMature(booking, now)))
        {
            if (await disputes.HasOpenDisputeAsync(booking.Id, CancellationToken.None)) continue;
            var result = await wallet.ReleaseMatureSettlementAsync(
                booking.Id, booking.CaregiverId!.Value, booking.EscrowAmount, booking.PlatformFeeAmount, now);
            if (result.IsFailure)
            {
                logger.LogWarning("Could not release mature settlement for booking {BookingId}: {Reason}", booking.Id, result.Error.Message);
                continue;
            }
            await settlements.MarkSettlementReleasedAsync(booking.Id, now);
        }
    }
}
