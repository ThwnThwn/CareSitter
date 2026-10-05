using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class ListMyDevicesQueryHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<ListMyDevicesQuery, Result<IReadOnlyList<DeviceResponse>>>
{
    public async Task<Result<IReadOnlyList<DeviceResponse>>> Handle(
        ListMyDevicesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        return Result.Success(await store.ListByUserAsync(userId, ct));
    }
}
