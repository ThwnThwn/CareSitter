using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record CareTaskPhotoResponse(
    Guid TaskId, Guid MediaId, string Url, DateTimeOffset UploadedAt);
