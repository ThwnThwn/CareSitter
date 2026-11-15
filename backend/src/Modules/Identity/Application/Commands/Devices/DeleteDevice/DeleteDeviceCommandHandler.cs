using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class DeleteDeviceCommandHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<DeleteDeviceCommand, Result>
{
    public async Task<Result> Handle(DeleteDeviceCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var device = await store.FindOwnedAsync(request.DeviceId, userId, ct);
        if (device is null) return Error.NotFound("device.not_found", "Không tìm thấy thiết bị.");
        store.Remove(device);
        await store.SaveChangesAsync(ct);
        return Result.Success();
    }
}
