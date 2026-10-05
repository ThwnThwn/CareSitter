using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.SelectCaregiver;

public sealed record SelectCaregiverCommand(Guid BookingId, Guid CaregiverId)
    : IRequest<Result<BookingResponse>>;
