using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain;

/// <summary>
/// Nhat ky kiem toan (gop booking_status_history + kyc history). Map sang bang audit_logs.
/// Bang khong co updated_at.
/// </summary>
public sealed class AuditLog : Entity
{
    private AuditLog() { } // EF

    private AuditLog(Guid id, string action, string entityType) : base(id)
    {
        Action = action;
        EntityType = entityType;
    }

    public Guid? ActorUserId { get; private set; }
    public string? ActorRole { get; private set; }
    public string Action { get; private set; } = null!;
    public string EntityType { get; private set; } = null!;
    public Guid? EntityId { get; private set; }

    /// <summary>jsonb snapshot truoc thay doi.</summary>
    public string? BeforeData { get; private set; }

    /// <summary>jsonb snapshot sau thay doi.</summary>
    public string? AfterData { get; private set; }

    /// <summary>inet dia chi IP.</summary>
    public string? IpAddress { get; private set; }
    public string? UserAgent { get; private set; }

    public static Result<AuditLog> Create(
        string action,
        string entityType,
        Guid? actorUserId = null,
        Guid? entityId = null,
        string? afterData = null,
        string? ipAddress = null,
        string? userAgent = null,
        string? beforeData = null,
        string? actorRole = null)
    {
        if (string.IsNullOrWhiteSpace(action))
            return Error.Validation("audit_log.action", "action la bat buoc.");
        if (string.IsNullOrWhiteSpace(entityType))
            return Error.Validation("audit_log.entity_type", "entity_type la bat buoc.");

        return new AuditLog(Guid.NewGuid(), action.Trim(), entityType.Trim())
        {
            ActorUserId = actorUserId,
            ActorRole = actorRole,
            EntityId = entityId,
            BeforeData = beforeData,
            AfterData = afterData,
            IpAddress = Normalize(ipAddress, 64),
            UserAgent = Normalize(userAgent, 500)
        };
    }

    private static string? Normalize(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrEmpty(normalized)) return null;
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }
}
