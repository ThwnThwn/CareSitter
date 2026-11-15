using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

internal interface IBookingCreationIdempotencyStore
{
    Task<Result<Domain.Booking>> ExecuteAsync(
        Guid customerId,
        Guid idempotencyKey,
        string payloadHash,
        Func<CancellationToken, Task<Result<Domain.Booking>>> create,
        CancellationToken ct);
}
