using System.Text.Json;
using CareSitter.Contracts.IntegrationEvents;

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
    public int AttemptCount { get; set; }
    public DateTimeOffset? NextAttemptOnUtc { get; set; }

    public static OutboxMessage Create(IIntegrationEvent integrationEvent) => new()
    {
        Id = integrationEvent.EventId,
        Type = integrationEvent.GetType().FullName
            ?? throw new InvalidOperationException("Integration event type must have a full name."),
        Payload = JsonSerializer.Serialize(integrationEvent, integrationEvent.GetType()),
        OccurredOnUtc = integrationEvent.OccurredOnUtc
    };

    public void MarkProcessed(DateTimeOffset processedOnUtc)
    {
        ProcessedOnUtc = processedOnUtc;
        Error = null;
        NextAttemptOnUtc = null;
    }

    public void MarkFailed(string error, DateTimeOffset failedOnUtc)
    {
        AttemptCount++;
        Error = error.Length <= 4000 ? error : error[..4000];
        var delaySeconds = Math.Min(300, Math.Pow(2, Math.Min(AttemptCount, 8)));
        NextAttemptOnUtc = failedOnUtc.AddSeconds(delaySeconds);
    }
}
