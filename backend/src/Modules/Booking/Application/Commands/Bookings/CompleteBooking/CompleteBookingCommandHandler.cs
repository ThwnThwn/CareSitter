using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CompleteBooking;

internal sealed class CompleteBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IDisputeLookupService disputeLookup,
    IBookingSyncService bookingSync,
    IBookingChatWriter bookingChat,
    IAuditLogger auditLogger,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<CompleteBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(CompleteBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BookingErrors.CaregiverMissing();

        bool isCustomerApprover = booking.CustomerId == userId;
        bool isAdmin = currentUser.IsInRole("ADMIN");
        if (!isCustomerApprover && !isAdmin)
            return BookingErrors.Forbidden();
        if (booking.Status != BookingStatus.CheckoutPendingReview)
            return BookingErrors.CompleteInvalidState();
        if (booking.NeedsReview && !isAdmin)
            return Error.Conflict("booking.complete.admin_review_required",
                "Ca chăm sóc có bất thường cần admin kiểm tra trước khi hoàn tất.");
        if (await disputeLookup.HasOpenDisputeAsync(booking.Id, ct))
            return BookingErrors.OpenDispute();

        var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
        var result = booking.Complete();
        if (result.IsFailure) return result.Error;

        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKOUT", "Ca chăm sóc hoàn thành"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Completed);
        await bookingChat.RecordSystemTransitionAsync(booking,
            BookingSyncEventTypes.Completed, "Ca chăm sóc đã hoàn tất.",
            booking.ActualEnd ?? DateTimeOffset.UtcNow,
            BookingChatTransitionEffect.StartPostShiftGrace, ct);
        await bookings.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("BOOKING_COMPLETED_AWAITING_SETTLEMENT", "Booking", booking.Id,
            new { status = oldStatus },
            new
            {
                status = BookingStatusPresenter.ToApi(booking.Status),
                booking.EscrowAmount,
                booking.PlatformFeeAmount,
                caregiverId,
                approvedBy = isAdmin ? "ADMIN" : "CUSTOMER",
                booking.DisputeWindowHours
            }, ct);
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
