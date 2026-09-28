using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingAcceptanceTransaction
{
    Task<Result<Domain.Booking>> ExecuteAsync(
        Guid bookingId,
        Func<Domain.Booking, CancellationToken, Task<Result>> mutation,
        CancellationToken ct = default);
}
