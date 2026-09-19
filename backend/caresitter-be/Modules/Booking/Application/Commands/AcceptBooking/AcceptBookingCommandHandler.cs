using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Application.Commands.AcceptBooking;

internal sealed class AcceptBookingCommandHandler(
    IBookingRepository bookings,
    BookingDbContext bookingDb,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMatchingService matching,
    BookingSyncService bookingSync,
    BookingPostCommitService postCommit,
    BookingResponseMapper responseMapper)
    : IRequestHandler<AcceptBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(AcceptBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (!currentUser.IsInRole("CAREGIVER")) return BookingErrors.Forbidden();

        var currentCaregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
        if (currentCaregiverId is null) return BookingErrors.Forbidden();

        await using var tx = await bookingDb.Database.BeginTransactionAsync(ct);
        var booking = await bookingDb.Bookings
            .FromSqlInterpolated($"SELECT * FROM booking.bookings WHERE id = {request.BookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingErrors.NotFound();

        var caregiverId = currentCaregiverId.Value;
        if (booking.CaregiverId is { } assignedCaregiverId)
        {
            if (assignedCaregiverId != caregiverId)
                return BookingErrors.AlreadyAccepted();
            caregiverId = assignedCaregiverId;
        }
        else
        {
            var offer = await bookings.GetActiveAssignmentReadOnlyAsync(
                request.BookingId, caregiverId, DateTimeOffset.UtcNow, ct);
            var hasAnyAssignment = await bookings.HasAnyAssignmentAsync(request.BookingId, ct);
            if (offer is null && hasAnyAssignment)
                return BookingErrors.OfferNotValid();

            if (offer is null)
            {
                var eligible = await matching.GetEligibleCaregiversAsync(request.BookingId, ct);
                if (!eligible.Any(x => x.CaregiverId == caregiverId))
                    return BookingErrors.CaregiverNotEligible();
            }
        }

        if (await bookings.HasCaregiverScheduleConflictAsync(booking.Id, caregiverId,
                booking.ScheduledStart, booking.ScheduledEnd, ct))
            return BookingErrors.CaregiverScheduleConflict();

        if (booking.CaregiverId.HasValue && booking.CaregiverId != caregiverId)
            return BookingErrors.AlreadyAccepted();
        if (booking.Status != BookingStatus.Confirmed && booking.Status != BookingStatus.Crisis)
            return BookingErrors.NotAwaitingAcceptance();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.AssignCaregiver(caregiverId);
        if (result.IsFailure) return result.Error;

        var slotHold = await bookings.GetActiveSlotHoldAsync(booking.Id, ct);
        if (slotHold is not null && slotHold.CaregiverId != caregiverId)
            return BookingErrors.CaregiverSlotHeld();
        if (slotHold is null)
        {
            var now = DateTimeOffset.UtcNow;
            var holdResult = CaregiverSlotHold.Create(
                booking.Id,
                caregiverId,
                booking.ScheduledStart,
                booking.ScheduledEnd,
                booking.ScheduledEnd > now ? booking.ScheduledEnd : now.AddMinutes(1));
            if (holdResult.IsFailure) return holdResult.Error;
            slotHold = holdResult.Value;
            slotHold.Commit();
            bookings.AddSlotHold(slotHold);
        }
        else
        {
            slotHold.Commit();
        }

        var acceptedOffer = await bookings.GetActiveAssignmentAsync(request.BookingId, caregiverId, ct);
        acceptedOffer?.Accept();
        var otherOffers = await bookings.GetOtherOfferedAssignmentsAsync(
            request.BookingId, caregiverId, ct);
        foreach (var otherOffer in otherOffers)
            otherOffer.Cancel();
        bookings.AddTimelineEvent(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKIN", "Caregiver đã nhận ca"));
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CaregiverAccepted);

        try
        {
            await bookings.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            await tx.RollbackAsync(ct);
            return BookingErrors.AlreadyAccepted();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            return BookingErrors.CaregiverScheduleConflict();
        }

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
