using System.Collections.Concurrent;
using System.Diagnostics.Metrics;

namespace CareSitter.Messaging.Kafka.Observability;

/// <summary>Low-cardinality metrics and consumer readiness state for messaging hosts.</summary>
public sealed class MessagingMetrics : IDisposable
{
    private readonly Meter _meter = new("CareSitter.Messaging", "1.0.0");
    private readonly ConcurrentDictionary<string, double> _lag = new();
    public Counter<long> PublishFailure { get; }
    public Counter<long> HandlerFailure { get; }
    public Counter<long> DeadLetters { get; }
    public volatile bool ConsumerHalted;
    public volatile bool ConsumerDegraded;

    /// <summary>Creates counters and an observable lag gauge without retaining event payloads.</summary>
    public MessagingMetrics()
    {
        PublishFailure = _meter.CreateCounter<long>("publish_failure");
        HandlerFailure = _meter.CreateCounter<long>("handler_failure");
        DeadLetters = _meter.CreateCounter<long>("dlq_count");
        _meter.CreateObservableGauge("consumer_lag", () => _lag.Select(x =>
            new Measurement<double>(x.Value, new KeyValuePair<string, object?>("partition", x.Key))));
    }

    /// <summary>Updates lag using the client's cached high watermark rather than a blocking query.</summary>
    public void ObserveLag(string topic, int partition, long high, long processedOffset)
    {
        if (high >= 0) _lag[$"{topic}:{partition}"] = Math.Max(0, high - processedOffset - 1);
    }

    /// <summary>Releases the meter when the owning host is disposed.</summary>
    public void Dispose() => _meter.Dispose();
}
