using CareSitter.Contracts.Services;
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
    IBookingSyncService bookingSync,
    IBookingPostCommitService postCommit,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<RescheduleBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(RescheduleBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (request.ScheduledStart <= clock.UtcNow)
            return BookingErrors.ScheduleMustBeFuture();
        var booking = await bookings.GetForCustomerAsync(request.BookingId, userId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.Status is not (BookingStatus.Draft or BookingStatus.PendingPayment or BookingStatus.Confirmed))
            return Error.Conflict("booking.reschedule", "Không thể dời lịch ở trạng thái hiện tại.");
        if (await bookings.HasBeneficiaryScheduleConflictAsync(booking.Id,
                booking.BeneficiaryId, request.ScheduledStart, request.ScheduledEnd, ct))
            return BookingErrors.BeneficiaryScheduleConflict();
        if (booking.CaregiverId is { } caregiverId && await bookings.HasCaregiverScheduleConflictAsync(
            booking.Id, caregiverId, request.ScheduledStart, request.ScheduledEnd, ct))
            return BookingErrors.CaregiverNewScheduleConflict();

        var quote = await pricing.QuoteAsync(booking.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsFailure) return quote.Error;
        if (booking.Status == BookingStatus.Confirmed && quote.Value.EscrowAmount != booking.EscrowAmount)
            return Error.Conflict("booking.reschedule.paid_price_change",
                "Lịch mới làm thay đổi số tiền đã thanh toán. Vui lòng liên hệ hỗ trợ để điều chỉnh đơn.");
        if (booking.PromotionId is not null && quote.Value.EscrowAmount != booking.EscrowAmount)
            return Error.Conflict("booking.promotion_reprice_required",
                "Lịch mới làm thay đổi giá của đơn có ưu đãi. Vui lòng tạo đơn mới để hệ thống kiểm tra lại promotion.");
        var changed = booking.Reschedule(request.ScheduledStart, request.ScheduledEnd);
        if (changed.IsFailure) return changed.Error;
        // Keep the paid financial snapshot, including fees and dispute window, immutable.
        if (booking.Status != BookingStatus.Confirmed)
        {
            var pricingApplied = booking.ApplyPricing(quote.Value.EscrowAmount,
                quote.Value.PlatformFeeAmount,
                quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson,
                quote.Value.DisputeWindowHours);
            if (pricingApplied.IsFailure) return pricingApplied.Error;
        }
        var slotHold = await bookings.GetActiveSlotHoldAsync(booking.Id, ct);
        if (slotHold is not null)
        {
            var moved = slotHold.Reschedule(request.ScheduledStart, request.ScheduledEnd);
            if (moved.IsFailure) return moved.Error;
        }
        bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Rescheduled);
        if (!await bookings.TrySaveSlotHoldChangesAsync(ct))
            return BookingErrors.CaregiverNewScheduleConflict();
        await postCommit.RunAsync("reschedule customer sync", () =>
            postCommit.PublishCustomerSyncEventAsync(booking, ct));
        return await responseMapper.ToResponseAsync(booking, ct);
    }
}
