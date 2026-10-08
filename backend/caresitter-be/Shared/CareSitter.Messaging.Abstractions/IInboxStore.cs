namespace CareSitter.Messaging.Abstractions;

/// <summary>Runs local database effects and an inbox marker in the same database transaction.</summary>
public interface IInboxStore
{
    /// <summary>Returns success for duplicates; failed effects roll back the inbox marker.</summary>
    Task<HandlerResult> ExecuteAsync(EventContext context, string handlerName,
        Func<CancellationToken, Task<HandlerResult>> action, CancellationToken ct);
    /// <summary>Deletes markers older than the supported replay window.</summary>
    Task<int> DeleteProcessedAsync(DateTimeOffset before, CancellationToken ct);
}
