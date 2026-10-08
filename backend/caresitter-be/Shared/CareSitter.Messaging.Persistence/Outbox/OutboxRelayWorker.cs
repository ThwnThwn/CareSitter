using System.Collections.Concurrent;
using System.Diagnostics.Metrics;
using CareSitter.Messaging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CareSitter.Messaging.Persistence.Outbox;

/// <summary>One host-level relay scans all module stores, renewing each record before publishing.</summary>
public sealed class OutboxRelayWorker(IServiceScopeFactory scopes, MessagingPersistenceOptions options,
    ILogger<OutboxRelayWorker> logger) : BackgroundService
{
    private readonly string _owner = $"{Environment.MachineName}:{Guid.NewGuid():N}";
    private readonly Meter _meter = new("CareSitter.Messaging.Outbox", "1.0.0");
    private readonly ConcurrentDictionary<string, OutboxStatistics> _statistics = new();

    /// <summary>Publishes claimed messages sequentially and keeps failed or uncertain deliveries pending.</summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _meter.CreateObservableGauge("outbox_pending", () => _statistics.Select(x => new Measurement<long>(x.Value.Pending,
            new KeyValuePair<string, object?>("module", x.Key))));
        _meter.CreateObservableGauge("outbox_oldest_age_seconds", () => _statistics.Select(x => new Measurement<double>(
            x.Value.Oldest is { } time ? Math.Max(0, (DateTimeOffset.UtcNow - time).TotalSeconds) : 0,
            new KeyValuePair<string, object?>("module", x.Key))));
        while (!stoppingToken.IsCancellationRequested)
        {
            await using var scope = scopes.CreateAsyncScope();
            var publisher = scope.ServiceProvider.GetRequiredService<IEventPublisher>();
            var serializer = scope.ServiceProvider.GetRequiredService<IEventSerializer>();
            foreach (var store in scope.ServiceProvider.GetServices<IOutboxStore>())
            {
                try
                {
                    var lease = TimeSpan.FromSeconds(options.LeaseSeconds);
                    var records = await store.ClaimAsync(_owner, options.BatchSize, lease, stoppingToken);
                    foreach (var record in records)
                    {
                        if (!await store.RenewAsync(record.Id, _owner, lease, stoppingToken)) continue;
                        try
                        {
                            var envelope = serializer.Deserialize(record.EnvelopeJson);
                            var result = await publisher.PublishAsync(envelope, stoppingToken);
                            await store.MarkPublishedAsync(record.Id, _owner, stoppingToken);
                            logger.LogInformation("Published event {EventId} correlation {CorrelationId} topic {Topic} partition {Partition} offset {Offset} attempt {Attempt}",
                                record.Id, envelope.CorrelationId, result.Topic, result.Partition, result.Offset, record.AttemptCount);
                        }
                        catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                        {
                            await store.MarkFailedAsync(record.Id, _owner, ex.GetType().Name, RetryDelay(record.AttemptCount), stoppingToken);
                            logger.LogWarning("Outbox {Module} event {EventId} attempt {Attempt} remains pending: {FailureType}",
                                store.Name, record.Id, record.AttemptCount, ex.GetType().Name);
                        }
                    }
                    _statistics[store.Name] = await store.GetStatisticsAsync(stoppingToken);
                }
                catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                { logger.LogWarning("Outbox {Module} scan failed: {FailureType}", store.Name, ex.GetType().Name); }
            }
            await Task.Delay(options.PollIntervalMs, stoppingToken);
        }
    }

    /// <summary>Returns bounded relay backoff while keeping the original identity and envelope intact.</summary>
    public static TimeSpan RetryDelay(int attempt) => TimeSpan.FromSeconds(
        attempt switch { <= 1 => 2, 2 => 5, 3 => 15, 4 => 60, _ => 300 }) + TimeSpan.FromMilliseconds(Random.Shared.Next(251));

    /// <summary>Disposes observable metrics with the worker.</summary>
    public override void Dispose() { _meter.Dispose(); base.Dispose(); }
}
