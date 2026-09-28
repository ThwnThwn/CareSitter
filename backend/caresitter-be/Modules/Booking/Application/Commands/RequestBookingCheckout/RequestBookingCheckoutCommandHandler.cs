using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;

internal sealed class RequestBookingCheckoutCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<RequestBookingCheckoutCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(
        RequestBookingCheckoutCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetByIdAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BookingErrors.CaregiverMissing();
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();
        if (await bookings.HasPendingCareTasksAsync(request.BookingId, ct))
            return BookingErrors.PendingTasks();
        if (await bookings.HasRequiredSkippedCareTasksAsync(request.BookingId, ct))
            booking.MarkNeedsReview();

        var oldStatus = BookingStatusPresenter.ToApi(booking.Status);
        var result = booking.RequestManualCheckout();
        if (result.IsFailure) return result.Error;
        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKOUT_MANUAL_REQUESTED", "Yêu cầu checkout thủ công"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CheckoutRequested);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("checkout-request status broadcast", () =>
            postCommit.BroadcastStatusAsync(request.BookingId, oldStatus,
                BookingStatusPresenter.ToApi(booking.Status), ct));
        await postCommit.RunAsync("checkout-request customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("checkout-request customer notification", () =>
            postCommit.NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver yêu cầu checkout",
                "Vui lòng kiểm tra và xác nhận hoàn tất ca chăm sóc.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
