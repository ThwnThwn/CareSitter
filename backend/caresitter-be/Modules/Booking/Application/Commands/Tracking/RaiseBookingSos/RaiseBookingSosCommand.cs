using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.RaiseBookingSos;

public sealed record RaiseBookingSosCommand(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
