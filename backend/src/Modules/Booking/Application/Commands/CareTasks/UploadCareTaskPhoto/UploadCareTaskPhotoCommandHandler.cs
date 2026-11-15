using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class UploadCareTaskPhotoCommandHandler(ICareTaskManager manager)
    : IRequestHandler<UploadCareTaskPhotoCommand, Result<CareTaskPhotoResponse>>
{
    public Task<Result<CareTaskPhotoResponse>> Handle(UploadCareTaskPhotoCommand request, CancellationToken ct) =>
        manager.UploadPhotoAsync(request, ct);
}
