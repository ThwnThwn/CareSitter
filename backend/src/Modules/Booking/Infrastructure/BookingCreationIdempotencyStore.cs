using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingCreationIdempotencyStore(BookingDbContext db, IClock clock)
    : IBookingCreationIdempotencyStore
{
    public async Task<Result<Domain.Booking>> ExecuteAsync(
        Guid customerId,
        Guid idempotencyKey,
        string payloadHash,
        Func<CancellationToken, Task<Result<Domain.Booking>>> create,
        CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var lockKey = $"booking-create:{customerId:N}:{idempotencyKey:N}";
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({lockKey}, 0))", ct);

        var existing = await db.BookingCreationRequests
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.CustomerId == customerId &&
                x.IdempotencyKey == idempotencyKey, ct);
        if (existing is not null)
        {
            if (!string.Equals(existing.PayloadHash, payloadHash, StringComparison.Ordinal))
                return BookingErrors.IdempotencyConflict();

            var booking = await db.Bookings
                .SingleOrDefaultAsync(x => x.Id == existing.BookingId, ct);
            return booking is null ? BookingErrors.IdempotencyRecordInvalid() : booking;
        }

        var created = await create(ct);
        if (created.IsFailure) return created.Error;

        db.BookingCreationRequests.Add(BookingCreationRequest.Create(
            customerId, idempotencyKey, payloadHash, created.Value.Id, clock.UtcNow));
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return created.Value;
    }
}
