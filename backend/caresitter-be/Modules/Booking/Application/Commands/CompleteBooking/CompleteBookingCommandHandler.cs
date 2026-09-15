using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.CompleteBooking;

internal sealed class CompleteBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IWalletService wallet,
    IDisputeLookupService disputeLookup,
    BookingSyncService bookingSync,
    BookingPostCommitService postCommit,
    BookingResponseMapper responseMapper)
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
        if (await disputeLookup.HasOpenDisputeAsync(booking.Id, ct))
            return BookingErrors.OpenDispute();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.Complete();
        if (result.IsFailure) return result.Error;

        var settleResult = await wallet.SettleAsync(booking.Id, caregiverId,
            booking.EscrowAmount, booking.PlatformFeeAmount, ct);
        if (settleResult.IsFailure) return settleResult.Error;

        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKOUT", "Ca chăm sóc hoàn thành"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Completed);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("complete status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus,
                BookingStatusCodec.ToApi(booking.Status), ct));
        await postCommit.RunAsync("complete customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("complete customer notification", () =>
            postCommit.NotifyBookingUserAsync(booking.CustomerId, booking, "Ca chăm sóc đã hoàn tất",
                "Lịch chăm sóc đã được xác nhận hoàn tất.", ct));
        await postCommit.RunAsync("complete caregiver notification", () =>
            postCommit.NotifyCaregiverAsync(booking, "Ca chăm sóc đã hoàn tất",
                "Escrow đã được xử lý cho ca chăm sóc này.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
