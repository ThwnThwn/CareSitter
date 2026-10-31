namespace CareSitter.Contracts.Services;

public sealed record UserNotificationMessage(
    Guid UserId,
    string Type,
    string Title,
    string? Body = null,
    IReadOnlyDictionary<string, string>? Data = null,
    Guid? EventId = null,
    DateTimeOffset? OccurredAt = null,
    bool SendPush = true);

public interface IUserNotificationService
{
    Task NotifyAsync(UserNotificationMessage message, CancellationToken ct = default);
}

public interface IPushNotificationService
{
    Task SendToUserAsync(UserNotificationMessage message, CancellationToken ct = default);
}
