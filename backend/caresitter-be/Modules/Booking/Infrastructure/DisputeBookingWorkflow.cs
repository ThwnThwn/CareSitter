using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class DisputeBookingWorkflow(
    BookingDbContext db,
    IPeopleLookupService people,
    IWalletService wallet,
    IBookingSyncService sync) : IDisputeBookingWorkflow
{
    public async Task<DisputeBookingSnapshot?> GetAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return null;

        Guid? caregiverUserId = null;
        if (booking.CaregiverId is { } caregiverId)
            caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);

        return ToSnapshot(booking, caregiverUserId);
    }

    public async Task<Result> OpenAsync(Guid bookingId, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (db.Database.IsRelational())
        {
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(hashtextextended({bookingId.ToString()}, 0))", ct);
        }
        if (await wallet.HasSettlementAsync(bookingId, ct))
            return Error.Conflict("support.dispute.settlement_released",
                "Booking đã giải ngân nên không thể mở tranh chấp mới.");

        var booking = await db.Bookings
            .FromSqlInterpolated($"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null)
            return Error.NotFound("support.dispute.booking_not_found", "Không tìm thấy booking.");

        if (booking.Status == BookingStatus.Disputed)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (!CanOpen(booking, DateTimeOffset.UtcNow))
            return Error.Conflict("support.dispute.invalid_state",
                "Booking chưa ở trạng thái cho phép khiếu nại hoặc chưa qua thời gian chờ no-show.");
        if (booking.Status == BookingStatus.Completed &&
            (booking.ActualEnd is null ||
             booking.ActualEnd.Value.AddHours(booking.DisputeWindowHours) < DateTimeOffset.UtcNow ||
             booking.SettlementReleasedAt is not null))
            return Error.Conflict("support.dispute.window_expired",
                "Booking đã hết thời hạn khiếu nại.");

        var transitioned = booking.TransitionTo(BookingStatus.Disputed);
        if (transitioned.IsFailure) return transitioned.Error;
        sync.WriteSyncEvent(booking, BookingSyncEventTypes.Disputed);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Result.Success();
    }

    public async Task<Result> ResolveAsync(
        Guid bookingId,
        string decision,
        long refundAmount,
        OriginalPaymentRefundState refundState,
        DateTimeOffset resolvedAt,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings
            .FromSqlInterpolated($"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null)
            return Error.NotFound("support.dispute.booking_not_found", "Không tìm thấy booking.");

        var target = decision == "CUSTOMER_WINS" &&
            (refundState is OriginalPaymentRefundState.Confirmed or
                OriginalPaymentRefundState.NotRequired)
                ? BookingStatus.Refunded
                : decision == "CUSTOMER_WINS"
                    ? BookingStatus.Disputed
                    : BookingStatus.Completed;
        if (target == BookingStatus.Disputed && booking.Status == BookingStatus.Disputed)
        {
            var pendingRefund = booking.RecordDisputeRefund(refundAmount);
            if (pendingRefund.IsFailure) return pendingRefund.Error;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (booking.Status == target)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (booking.Status != BookingStatus.Disputed)
            return Error.Conflict("support.dispute.invalid_state",
                "Booking không còn ở trạng thái tranh chấp.");

        var recorded = booking.RecordDisputeRefund(refundAmount);
        if (recorded.IsFailure) return recorded.Error;
        var transitioned = booking.TransitionTo(target);
        if (transitioned.IsFailure) return transitioned.Error;
        if (target == BookingStatus.Completed)
        {
            var marked = booking.MarkSettlementReleased(resolvedAt);
            if (marked.IsFailure) return marked.Error;
        }

        sync.WriteSyncEvent(booking,
            target == BookingStatus.Refunded
                ? BookingSyncEventTypes.Refunded
                : BookingSyncEventTypes.Completed);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Result.Success();
    }

    private static DisputeBookingSnapshot ToSnapshot(
        Domain.Booking booking, Guid? caregiverUserId) => new(
        booking.Id,
        booking.CustomerId,
        booking.CaregiverId,
        caregiverUserId,
        BookingStatusCodec.ToApi(booking.Status),
        booking.EscrowAmount,
        booking.CustomerPayableAmount,
        booking.PromotionSubsidyAmount,
        booking.PlatformFeeAmount,
        booking.DisputeWindowHours,
        booking.ScheduledStart,
        booking.ActualStart,
        booking.ActualEnd,
        booking.SettlementReleasedAt);

    private static bool CanOpen(Domain.Booking booking, DateTimeOffset now)
    {
        if (booking.Status is BookingStatus.CheckoutPendingReview or BookingStatus.Completed)
            return true;

        return (booking.Status is BookingStatus.Confirmed or
                   BookingStatus.CaregiverAccepted or BookingStatus.CaregiverEnRoute) &&
               booking.CaregiverId is not null &&
               booking.ActualStart is null &&
               now >= booking.ScheduledStart.AddMinutes(30);
    }
}
