using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingAcceptanceTransaction(BookingDbContext db)
    : IBookingAcceptanceTransaction
{
    public async Task<Result<Domain.Booking>> ExecuteAsync(
        Guid bookingId,
        Func<Domain.Booking, CancellationToken, Task<Result>> mutation,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingErrors.NotFound();

        var result = await mutation(booking, ct);
        if (result.IsFailure)
        {
            await tx.RollbackAsync(ct);
            return result.Error;
        }

        try
        {
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return booking;
        }
        catch (DbUpdateConcurrencyException)
        {
            await tx.RollbackAsync(ct);
            return BookingErrors.AlreadyAccepted();
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.ExclusionViolation } or PostgresException
            { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: "uq_active_slot_hold_booking" })
        {
            await tx.RollbackAsync(ct);
            return BookingErrors.CaregiverScheduleConflict();
        }
    }
}
