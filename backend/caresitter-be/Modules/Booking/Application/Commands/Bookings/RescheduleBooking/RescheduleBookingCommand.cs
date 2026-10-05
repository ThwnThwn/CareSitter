using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;

public sealed record RescheduleBookingCommand(
    Guid BookingId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<BookingResponse>>;
