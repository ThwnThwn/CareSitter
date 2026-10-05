using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record UploadCareTaskPhotoCommand(
    Guid BookingId, Guid TaskId, Stream Content, string FileName,
    string ContentType, long Length) : IRequest<Result<CareTaskPhotoResponse>>;
