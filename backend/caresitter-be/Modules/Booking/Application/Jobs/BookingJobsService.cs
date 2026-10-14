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
        {
            try
            {
                var credited = await wallet.RefundToCustomerWalletAsync(booking.Id, booking.CustomerId);
                if (credited.IsFailure)
                {
                    logger.LogWarning("Could not credit customer wallet for unmatched booking {BookingId}: {Reason}",
                        booking.Id, credited.Error.Message);
                    continue;
                }
                var refunded = await settlements.MarkRefundedAsync(booking.Id);
                if (refunded is not null) await notifier.RefundedAsync(refunded);
            }
            catch (Exception error)
            {
                logger.LogError(error, "Failed to refund unmatched booking {BookingId}", booking.Id);
            }
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
