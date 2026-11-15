namespace CareSitter.Messaging.Abstractions;

/// <summary>A scoped application handler. Implementations must be idempotent.</summary>
public interface IEventHandler<in TEvent>
{
    /// <summary>Processes a delivery and classifies its outcome for the consumer retry policy.</summary>
    Task<HandlerResult> HandleAsync(TEvent message, EventContext context, CancellationToken ct);
}
