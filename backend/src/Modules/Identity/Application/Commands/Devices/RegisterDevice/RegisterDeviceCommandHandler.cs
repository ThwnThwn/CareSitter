using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class RegisterDeviceCommandHandler(
    IIdentityDeviceStore store, ICurrentUser currentUser)
    : IRequestHandler<RegisterDeviceCommand, Result<DeviceRegistrationResult>>
{
    public async Task<Result<DeviceRegistrationResult>> Handle(
        RegisterDeviceCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var platform = request.Platform?.Trim().ToUpperInvariant() ?? string.Empty;
        var pushToken = string.IsNullOrWhiteSpace(request.PushToken) ? null : request.PushToken.Trim();

        if (pushToken is not null)
        {
            var tokenOwner = await store.FindByPushTokenAsync(pushToken, ct);
            if (tokenOwner is not null && tokenOwner.UserId != userId)
                store.Remove(tokenOwner);
        }

        var existing = await store.FindByUserAndPlatformAsync(userId, platform, ct);
        if (existing is not null)
        {
            existing.UpdatePushToken(pushToken);
            if (request.DeviceName is not null) existing.UpdateDeviceName(request.DeviceName);
            await store.SaveChangesAsync(ct);
            return new DeviceRegistrationResult(ToResponse(existing), false);
        }

        var created = UserDevice.Create(userId, platform);
        if (created.IsFailure) return created.Error;
        created.Value.UpdatePushToken(pushToken);
        if (request.DeviceName is not null) created.Value.UpdateDeviceName(request.DeviceName);
        store.Add(created.Value);
        await store.SaveChangesAsync(ct);
        return new DeviceRegistrationResult(ToResponse(created.Value), true);
    }

    private static DeviceResponse ToResponse(UserDevice device) => new(
        device.Id, device.Platform, device.DeviceName, device.PushToken is not null,
        device.BiometricEnabled, device.LastSeenAt, device.CreatedAt);
}
