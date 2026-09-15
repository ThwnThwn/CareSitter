using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Http;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

public sealed record UploadCheckInSelfieCommand(Guid BookingId, IFormFile? File)
    : IRequest<Result<CheckInSelfieResponse>>;
