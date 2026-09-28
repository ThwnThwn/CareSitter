using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.SelectCaregiver;

internal sealed class SelectCaregiverCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IMatchingService matching,
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<SelectCaregiverCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(SelectCaregiverCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetForCustomerAsync(request.BookingId, userId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (await bookings.HasCaregiverScheduleConflictAsync(booking.Id, request.CaregiverId,
            booking.ScheduledStart, booking.ScheduledEnd, ct))
            return BookingErrors.CaregiverScheduleConflict();
        var suggestions = await matching.GetSuggestedCaregiversAsync(request.BookingId, ct);
        if (!suggestions.Any(x => x.CaregiverId == request.CaregiverId))
            return BookingErrors.CaregiverNotSuggested();

        var holdUntil = booking.PaymentDeadline.AddMinutes(15);
        var existingHold = await bookings.GetActiveSlotHoldAsync(booking.Id, ct);
        if (existingHold is not null && existingHold.CaregiverId == request.CaregiverId)
        {
            existingHold.ExtendUntil(holdUntil);
        }
        else
        {
            existingHold?.Release();
            var holdResult = CaregiverSlotHold.Create(booking.Id, request.CaregiverId,
                booking.ScheduledStart, booking.ScheduledEnd, holdUntil);
            if (holdResult.IsFailure) return holdResult.Error;
            bookings.AddSlotHold(holdResult.Value);
        }

        var result = booking.SelectCaregiver(request.CaregiverId);
        if (result.IsFailure) return result.Error;
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.CaregiverSelected);
        if (!await bookings.TrySaveSlotHoldChangesAsync(ct))
            return BookingErrors.CaregiverSlotHeld();
        await postCommit.RunAsync("caregiver selection customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        if (booking.Status == BookingStatus.Confirmed)
        {
            await postCommit.RunAsync("caregiver selection notification", () =>
                postCommit.NotifyCaregiverAsync(booking, "Bạn có lịch chăm sóc mới",
                    "Khách hàng đã thanh toán và đang chờ bạn xác nhận ca.", ct));
        }
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
