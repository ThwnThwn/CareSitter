using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record DeviceResponse(
    Guid Id,
    string Platform,
    string? DeviceName,
    bool HasPushToken,
    bool BiometricEnabled,
    DateTimeOffset? LastSeenAt,
    DateTimeOffset CreatedAt);
