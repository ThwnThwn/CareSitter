namespace CareSitter.Messaging.Persistence.Inbox;

/// <summary>A successful local effect marker, committed atomically with the effect itself.</summary>
public sealed class InboxMessage
{
    public string ConsumerName { get; set; } = "";
    public string HandlerName { get; set; } = "";
    public Guid EventId { get; set; }
    public string EventType { get; set; } = "";
    public DateTimeOffset ProcessedAt { get; set; }
}
