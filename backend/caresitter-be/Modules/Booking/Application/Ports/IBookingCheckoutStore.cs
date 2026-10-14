using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingCheckoutStore
{
    Task<IReadOnlyList<BookingEntity>> RecordLateCheckinsAsync(DateTimeOffset cutoff, CancellationToken ct = default);
    IAsyncEnumerable<BookingJobChange> RequestExpiredCheckoutsAsync(DateTimeOffset cutoff, CancellationToken ct = default);
    IAsyncEnumerable<BookingJobChange> ConfirmPendingCheckoutsAsync(DateTimeOffset cutoff, CancellationToken ct = default);
}
