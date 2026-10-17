using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingSettlementStore
{
    IAsyncEnumerable<BookingEntity> UnmatchedBookingsAsync(CancellationToken ct = default);
    IAsyncEnumerable<BookingEntity> BookingsAwaitingRefundAsync(CancellationToken ct = default);
    Task<BookingEntity?> MarkRefundedAsync(Guid bookingId, CancellationToken ct = default);
    Task<IReadOnlyList<BookingEntity>> UnreleasedSettlementsAsync(CancellationToken ct = default);
    Task MarkSettlementReleasedAsync(Guid bookingId, DateTimeOffset now, CancellationToken ct = default);
}
