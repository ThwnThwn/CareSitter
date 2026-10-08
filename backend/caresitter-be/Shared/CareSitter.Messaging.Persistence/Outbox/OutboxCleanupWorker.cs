using CareSitter.Messaging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CareSitter.Messaging.Persistence.Outbox;

/// <summary>Periodically cleans completed outboxes and expired local inbox markers.</summary>
public sealed class OutboxCleanupWorker(IServiceScopeFactory scopes, MessagingPersistenceOptions options,
    ILogger<OutboxCleanupWorker> logger) : BackgroundService
{
    /// <summary>Retains unresolved outbox messages and keeps inboxes beyond the supported topic replay window.</summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                foreach (var store in scope.ServiceProvider.GetServices<IOutboxStore>())
                    await store.DeletePublishedAsync(DateTimeOffset.UtcNow.AddDays(-options.OutboxRetentionDays), stoppingToken);
                foreach (var store in scope.ServiceProvider.GetServices<IInboxStore>())
                    await store.DeleteProcessedAsync(DateTimeOffset.UtcNow.AddDays(-options.InboxRetentionDays), stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            { logger.LogWarning("Messaging cleanup failed: {FailureType}", ex.GetType().Name); }
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
