using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Application;

internal sealed record BookingJobChange(BookingEntity Booking, string OldStatus, DateTimeOffset ChangedAt);
