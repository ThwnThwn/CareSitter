namespace CareSitter.Infrastructure.Outbox;

/// <summary>
/// Ban ghi outbox: luu integration event trong cung transaction nghiep vu de dam bao at-least-once.
/// Moi module so huu 1 bang outbox trong schema cua minh.
/// </summary>
public sealed class OutboxMessage
{
    public Guid Id { get; set; }
    public string Type { get; set; } = default!;
    public string Payload { get; set; } = default!;
    public DateTimeOffset OccurredOnUtc { get; set; }
    public DateTimeOffset? ProcessedOnUtc { get; set; }
    public string? Error { get; set; }
}
