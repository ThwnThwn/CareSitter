using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

public sealed record UploadCheckInSelfieCommand(
    Guid BookingId,
    Stream? Content,
    string FileName,
    string ContentType,
    long Length)
    : IRequest<Result<CheckInSelfieResponse>>;
