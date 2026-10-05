using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record OpenGpsSessionCommand(Guid BookingId, Guid SourceInstanceId)
    : IRequest<Result<LiveTrackingSessionResponse>>;
