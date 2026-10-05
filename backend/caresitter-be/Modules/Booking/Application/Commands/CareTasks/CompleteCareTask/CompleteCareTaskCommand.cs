using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record CompleteCareTaskCommand(Guid BookingId, Guid TaskId)
    : IRequest<Result<CareTaskResponse>>;
