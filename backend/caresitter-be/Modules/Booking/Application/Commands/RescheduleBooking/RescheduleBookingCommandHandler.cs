using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;

internal sealed class RescheduleBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IClock clock,
    IPricingService pricing,
    BookingSyncService bookingSync,
    BookingPostCommitService postCommit,
    BookingResponseMapper responseMapper)
    : IRequestHandler<RescheduleBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(RescheduleBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (request.ScheduledStart <= clock.UtcNow)
            return BookingErrors.ScheduleMustBeFuture();
        var booking = await bookings.GetForCustomerAsync(request.BookingId, userId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CaregiverId is { } caregiverId && await bookings.HasCaregiverScheduleConflictAsync(
            booking.Id, caregiverId, request.ScheduledStart, request.ScheduledEnd, ct))
            return BookingErrors.CaregiverNewScheduleConflict();

        var quote = await pricing.QuoteAsync(booking.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsFailure) return quote.Error;
        var changed = booking.Reschedule(request.ScheduledStart, request.ScheduledEnd);
        if (changed.IsFailure) return changed.Error;
        booking.ApplyPricing(quote.Value.EscrowAmount, quote.Value.PlatformFeeAmount,
            quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson);
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Rescheduled);
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("reschedule customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
