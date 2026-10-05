using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.AcceptBooking;

internal sealed class AcceptBookingCommandHandler(
    IBookingRepository bookings,
    IBookingAcceptanceTransaction acceptanceTransaction,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMatchingService matching,
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<AcceptBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(AcceptBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (!currentUser.IsInRole("CAREGIVER")) return BookingErrors.Forbidden();

        var currentCaregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
        if (currentCaregiverId is null) return BookingErrors.Forbidden();

        var caregiverId = currentCaregiverId.Value;
        var oldStatus = string.Empty;
        IReadOnlyList<BookingAssignment> otherOffers = [];
        var accepted = await acceptanceTransaction.ExecuteAsync(request.BookingId,
            async (booking, innerCt) =>
            {
                // An offer or customer selection can outlive the caregiver's KYC approval.
                if (!await people.IsCaregiverApprovedAsync(caregiverId, innerCt))
                    return BookingErrors.CaregiverNotEligible();

                if (booking.CaregiverId is { } assignedCaregiverId)
                {
                    if (assignedCaregiverId != caregiverId)
                        return BookingErrors.AlreadyAccepted();
                }
                else
                {
                    var offer = await bookings.GetActiveAssignmentReadOnlyAsync(
                        request.BookingId, caregiverId, DateTimeOffset.UtcNow, innerCt);
                    var hasAnyAssignment = await bookings.HasAnyAssignmentAsync(
                        request.BookingId, innerCt);
                    if (offer is null && hasAnyAssignment)
                        return BookingErrors.OfferNotValid();
                    if (offer is null)
                    {
                        var eligible = await matching.GetEligibleCaregiversAsync(
                            request.BookingId, innerCt);
                        if (!eligible.Any(x => x.CaregiverId == caregiverId))
                            return BookingErrors.CaregiverNotEligible();
                    }
                }

                if (await bookings.HasCaregiverScheduleConflictAsync(booking.Id, caregiverId,
                        booking.ScheduledStart, booking.ScheduledEnd, innerCt))
                    return BookingErrors.CaregiverScheduleConflict();
                if (booking.CaregiverId.HasValue && booking.CaregiverId != caregiverId)
                    return BookingErrors.AlreadyAccepted();
                if (booking.Status is not (BookingStatus.Confirmed or BookingStatus.Crisis))
                    return BookingErrors.NotAwaitingAcceptance();

                oldStatus = BookingStatusPresenter.ToApi(booking.Status);
                var assigned = booking.AssignCaregiver(caregiverId);
                if (assigned.IsFailure) return assigned.Error;

                var slotHold = await bookings.GetActiveSlotHoldAsync(booking.Id, innerCt);
                if (slotHold is not null && slotHold.CaregiverId != caregiverId)
                    return BookingErrors.CaregiverSlotHeld();
                if (slotHold is null)
                {
                    var now = DateTimeOffset.UtcNow;
                    var hold = CaregiverSlotHold.Create(booking.Id, caregiverId,
                        booking.ScheduledStart, booking.ScheduledEnd,
                        booking.ScheduledEnd > now ? booking.ScheduledEnd : now.AddMinutes(1));
                    if (hold.IsFailure) return hold.Error;
                    slotHold = hold.Value;
                    slotHold.Commit();
                    bookings.AddSlotHold(slotHold);
                }
                else
                {
                    slotHold.Commit();
                }

                var acceptedOffer = await bookings.GetActiveAssignmentAsync(
                    request.BookingId, caregiverId, innerCt);
                acceptedOffer?.Accept();
                otherOffers = await bookings.GetOtherOfferedAssignmentsAsync(
                    request.BookingId, caregiverId, innerCt);
                foreach (var otherOffer in otherOffers) otherOffer.Cancel();
                bookings.AddTimelineEvent(CareTimelineEvent.Create(
                    booking.Id, caregiverId, "CHECKIN", "Caregiver đã nhận ca"));
                bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CaregiverAccepted);
                return Result.Success();
            }, ct);
        if (accepted.IsFailure) return accepted.Error;
        var booking = accepted.Value;

        await postCommit.RunAsync("accepted offer update", () =>
            postCommit.PublishOfferChangedAsync(caregiverId, request.BookingId, "accepted", ct));
        foreach (var otherOffer in otherOffers)
            await postCommit.RunAsync("cancelled offer update", () =>
                postCommit.PublishOfferChangedAsync(otherOffer.CaregiverId, request.BookingId, "cancelled", ct));

        // Lưu inbox trước khi gửi SignalR để customer có thể refresh badge ngay
        // khi nhận event realtime, không gặp race với transaction notification.
        await postCommit.RunAsync("accepted customer notification", () =>
            postCommit.NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đã nhận ca",
                "Caregiver đã xác nhận lịch chăm sóc của bạn.", ct));
        await postCommit.RunAsync("accepted status broadcast", () =>
            postCommit.BroadcastAcceptedStatusAsync(booking, oldStatus, ct));
        await postCommit.RunAsync("accepted customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
