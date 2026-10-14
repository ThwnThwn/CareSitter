using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingJobNotifier
{
    Task LateCheckinAsync(BookingEntity booking, CancellationToken ct = default);
    Task CheckoutRequestedAsync(BookingJobChange change, CancellationToken ct = default);
    Task AutoConfirmedAsync(BookingJobChange change, CancellationToken ct = default);
    Task RefundedAsync(BookingEntity booking, CancellationToken ct = default);
}
