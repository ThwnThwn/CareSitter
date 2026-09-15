using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

internal sealed class PostBookingGpsCommandHandler
    : IRequestHandler<PostBookingGpsCommand, Result<Unit>>
{
    public Task<Result<Unit>> Handle(PostBookingGpsCommand request, CancellationToken ct) =>
        Task.FromResult<Result<Unit>>(BookingErrors.GpsTrackingDisabled());
}
