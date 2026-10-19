using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CancelBooking;

internal sealed class CancelBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IClock clock,
    IPromotionService promotions,
    IBookingSyncService bookingSync,
    IBookingChatWriter bookingChat,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<CancelBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(CancelBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetForCustomerAsync(request.BookingId, userId, ct);
        if (booking is null) return BookingErrors.NotFound();
        var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
        var cancelledAt = clock.UtcNow;
        var policy = BookingCancellationPolicy.Evaluate(booking, cancelledAt);
        if (policy.IsFailure) return policy.Error;
        var result = booking.Cancel(userId, "CUSTOMER", request.Reason, cancelledAt);
        if (result.IsFailure) return result.Error;
        if (policy.Value.RefundAmount > 0)
        {
            var scheduledRefund = booking.ScheduleOriginalPaymentRefund(
                policy.Value.RefundAmount);
            if (scheduledRefund.IsFailure) return scheduledRefund.Error;
        }
        var slotHolds = await bookings.GetActiveSlotHoldsAsync(booking.Id, ct);
        foreach (var slotHold in slotHolds)
            slotHold.Release();
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Cancelled);
        await bookingChat.RecordSystemTransitionAsync(booking,
            BookingSyncEventTypes.Cancelled, "Lịch chăm sóc đã bị hủy.", cancelledAt,
            BookingChatTransitionEffect.ScheduleRetention, ct);
        await bookings.SaveChangesAsync(ct);
        await promotions.ReleaseAsync(booking.Id, booking.CustomerId,
            "BOOKING_CANCELLED", ct);
        await postCommit.RunAsync("cancel status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus, "cancelled", ct));
        await postCommit.RunAsync("cancel customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("cancel caregiver notification", () =>
            postCommit.NotifyCaregiverAsync(booking, "Lịch chăm sóc đã bị hủy",
                "Khách hàng đã hủy lịch chăm sóc.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
