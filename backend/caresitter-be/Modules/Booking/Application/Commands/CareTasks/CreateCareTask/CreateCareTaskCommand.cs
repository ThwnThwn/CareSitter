using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record CreateCareTaskCommand(
    Guid BookingId, string Name, string? Description)
    : IRequest<Result<CareTaskResponse>>;
