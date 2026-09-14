using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Domain;

/// <summary>
/// Notification inbox (da doc/chua doc) cho 1 user. Map sang bang support.notifications.
/// Co created_at, KHONG co updated_at.
/// </summary>
public sealed class Notification : Entity
{
    private Notification() { } // EF

    private Notification(
        Guid id,
        Guid userId,
        string type,
        string title,
        string? body,
        string? data) : base(id)
    {
        UserId = userId;
        Type = type;
        Title = title;
        Body = body;
        Data = data;
    }

    public Guid UserId { get; private set; }

    /// <summary>Allowed values: BOOKING, CARE_TIMELINE, PAYMENT, PROMOTION, SYSTEM, SOS, BOOKING_OFFER, MATCHING_FAILED.</summary>
    public string Type { get; private set; } = "SYSTEM";

    public string Title { get; private set; } = string.Empty;
    public string? Body { get; private set; }

    /// <summary>jsonb — payload + deep_link.</summary>
    public string? Data { get; private set; }

    public DateTimeOffset? ReadAt { get; private set; }

    public static Result<Notification> Create(
        Guid userId,
        string type,
        string title,
        string? body = null,
        string? data = null)
    {
        if (userId == Guid.Empty)
            return Error.Validation("notification.user", "user_id không được rỗng.");
        if (string.IsNullOrWhiteSpace(type))
            return Error.Validation("notification.type", "type không được rỗng.");
        if (string.IsNullOrWhiteSpace(title))
            return Error.Validation("notification.title", "title không được rỗng.");

        return new Notification(Guid.NewGuid(), userId, type, title, body, data);
    }

    public void MarkRead()
    {
        ReadAt ??= DateTimeOffset.UtcNow;
    }
}
