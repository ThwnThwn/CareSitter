using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain;

/// <summary>
/// Thiet bi cua người dùng (push token, biometric). Map sang bang user_devices.
/// Bang khong co updated_at.
/// </summary>
public sealed class UserDevice : Entity
{
    private UserDevice() { } // EF

    private UserDevice(Guid id, Guid userId, string platform) : base(id)
    {
        UserId = userId;
        Platform = platform;
    }

    public Guid UserId { get; private set; }

    /// <summary>Allowed values: IOS, ANDROID, WEB.</summary>
    public string Platform { get; private set; } = null!;
    public string? PushToken { get; private set; }
    public string? DeviceName { get; private set; }
    public bool BiometricEnabled { get; private set; }
    public DateTimeOffset? LastSeenAt { get; private set; }

    public static Result<UserDevice> Create(Guid userId, string platform)
    {
        if (userId == Guid.Empty)
            return Error.Validation("user_device.user_id", "user_id la bat buoc.");
        if (string.IsNullOrWhiteSpace(platform))
            return Error.Validation("user_device.platform", "platform la bat buoc.");

        return new UserDevice(Guid.NewGuid(), userId, platform.Trim());
    }

    public void UpdatePushToken(string? token)
    {
        PushToken = token;
        LastSeenAt = DateTimeOffset.UtcNow;
    }

    public void UpdateDeviceName(string? name)
    {
        DeviceName = name;
    }

    public void UpdateLastSeen()
    {
        LastSeenAt = DateTimeOffset.UtcNow;
    }
}
