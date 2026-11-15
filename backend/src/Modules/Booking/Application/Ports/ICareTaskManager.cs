using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal interface ICareTaskManager
{
    Task<Result<IReadOnlyList<CareTaskResponse>>> ListAsync(
        Guid bookingId, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> CreateAsync(
        Guid bookingId, string name, string? description, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> CompleteAsync(
        Guid bookingId, Guid taskId, CancellationToken ct = default);
    Task<Result<CareTaskPhotoResponse>> UploadPhotoAsync(
        UploadCareTaskPhotoCommand request, CancellationToken ct = default);
    Task<Result<CareTaskResponse>> SkipAsync(
        Guid bookingId, Guid taskId, string reason, CancellationToken ct = default);
}
