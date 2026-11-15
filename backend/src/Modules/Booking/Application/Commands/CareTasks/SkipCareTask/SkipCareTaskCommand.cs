using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record SkipCareTaskCommand(Guid BookingId, Guid TaskId, string SkipReason)
    : IRequest<Result<CareTaskResponse>>;
