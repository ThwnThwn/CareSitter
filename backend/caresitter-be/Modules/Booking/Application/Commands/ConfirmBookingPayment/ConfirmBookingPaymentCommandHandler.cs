using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Application.Commands.ConfirmBookingPayment;

internal sealed class ConfirmBookingPaymentCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IWalletService wallet,
    IMatchingService matching,
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper,
    ILogger<ConfirmBookingPaymentCommandHandler> logger)
    : IRequestHandler<ConfirmBookingPaymentCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(ConfirmBookingPaymentCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await bookings.GetForCustomerAsync(request.BookingId, userId, ct);
        if (booking is null) return BookingErrors.NotFound();

        CaregiverSlotHold? slotHold = null;
        if (booking.CaregiverId is { } caregiverId && booking.Status == BookingStatus.PendingPayment)
        {
            var holdUntil = booking.PaymentDeadline.AddMinutes(15);
            slotHold = await bookings.GetActiveSlotHoldAsync(booking.Id, ct);
            if (slotHold is not null && slotHold.CaregiverId == caregiverId)
            {
                slotHold.ExtendUntil(holdUntil);
            }
            else
            {
                slotHold?.Release();
                var holdResult = CaregiverSlotHold.Create(booking.Id, caregiverId,
                    booking.ScheduledStart, booking.ScheduledEnd, holdUntil);
                if (holdResult.IsFailure) return holdResult.Error;
                slotHold = holdResult.Value;
                bookings.AddSlotHold(slotHold);
            }
            if (!await bookings.TrySaveSlotHoldChangesAsync(ct))
                return BookingErrors.CaregiverSlotHeld();
        }

        var lockResult = await wallet.LockEscrowAsync(booking.Id, booking.EscrowAmount,
            $"booking-escrow-{booking.Id}", ct);
        if (lockResult.IsFailure)
        {
            slotHold?.Release();
            if (slotHold is not null) await bookings.SaveChangesAsync(ct);
            return lockResult.Error;
        }

        var result = booking.ConfirmPayment();
        if (result.IsFailure)
        {
            slotHold?.Release();
            if (slotHold is not null) await bookings.SaveChangesAsync(ct);
            var releaseResult = await wallet.ReleaseEscrowAsync(booking.Id, booking.EscrowAmount, ct);
            if (releaseResult.IsFailure)
            {
                logger.LogError("Escrow release failed after ConfirmPayment rejection for booking {BookingId}: {Error}",
                    booking.Id, releaseResult.Error.Message);
            }
            return result.Error;
        }
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.PaymentConfirmed);
        slotHold?.Commit();
        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("payment customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        await postCommit.RunAsync("caregiver matching", () =>
            matching.OfferTopCandidatesAsync(request.BookingId, ct));
        await postCommit.RunAsync("payment caregiver notification", () =>
            postCommit.NotifyCaregiverAsync(booking, "Bạn có lịch chăm sóc mới",
                "Khách hàng đã thanh toán và đang chờ bạn xác nhận ca.", ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
