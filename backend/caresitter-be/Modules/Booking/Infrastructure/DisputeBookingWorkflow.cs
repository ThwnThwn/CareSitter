using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class DisputeBookingWorkflow(
    BookingDbContext db,
    IPeopleLookupService people,
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
        if (booking.Status is not (BookingStatus.CheckoutPendingReview or BookingStatus.Completed))
            return Error.Conflict("support.dispute.invalid_state",
                "Chỉ có thể khiếu nại booking đang chờ xác nhận hoặc đã hoàn thành.");
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

    public async Task<Result> ResolveAsync(Guid bookingId, string decision,
        DateTimeOffset resolvedAt, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings
            .FromSqlInterpolated($"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null)
            return Error.NotFound("support.dispute.booking_not_found", "Không tìm thấy booking.");

        var target = decision == "CUSTOMER_WINS"
            ? BookingStatus.Refunded
            : BookingStatus.Completed;
        if (booking.Status == target)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (booking.Status != BookingStatus.Disputed)
            return Error.Conflict("support.dispute.invalid_state",
                "Booking không còn ở trạng thái tranh chấp.");

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
        booking.PlatformFeeAmount,
        booking.DisputeWindowHours,
        booking.ActualEnd,
        booking.SettlementReleasedAt);
}
