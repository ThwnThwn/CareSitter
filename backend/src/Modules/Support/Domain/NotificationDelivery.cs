namespace CareSitter.Modules.Support.Domain;

/// <summary>Support-owned channel state with an expiring, token-fenced delivery claim.</summary>
public sealed class NotificationDelivery
{
    public Guid EventId { get; set; }
    public string Channel { get; set; } = "push";
    public Guid NotificationId { get; set; }
    public string Status { get; set; } = "Pending";
    public Guid? ClaimToken { get; set; }
    public DateTimeOffset? LeaseUntil { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    public string? LastError { get; set; }
}
