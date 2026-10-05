using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record ListCareTasksQuery(Guid BookingId)
    : IRequest<Result<IReadOnlyList<CareTaskResponse>>>;
