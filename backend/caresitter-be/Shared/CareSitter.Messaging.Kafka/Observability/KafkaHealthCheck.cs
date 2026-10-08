using CareSitter.Messaging.Kafka.Configuration;
using Confluent.Kafka;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace CareSitter.Messaging.Kafka.Observability;

/// <summary>Checks broker metadata and exposes halted/degraded consumer state.</summary>
public sealed class KafkaHealthCheck(KafkaOptions options, MessagingMetrics metrics) : IHealthCheck
{
    /// <summary>Probes the broker within a finite timeout without publishing a test message.</summary>
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        if (metrics.ConsumerHalted) return HealthCheckResult.Unhealthy("The consumer is halted on a poison message.");
        if (metrics.ConsumerDegraded) return HealthCheckResult.Degraded("The consumer has an unresolved delivery failure.");
        try
        {
            using var admin = new AdminClientBuilder(new AdminClientConfig { BootstrapServers = options.BootstrapServers }).Build();
            var metadata = await Task.Run(() => admin.GetMetadata(TimeSpan.FromSeconds(3)), ct);
            return metadata.Brokers.Count > 0 ? HealthCheckResult.Healthy() : HealthCheckResult.Degraded("No broker metadata.");
        }
        catch (Exception e) when (e is not OperationCanceledException)
        { return HealthCheckResult.Degraded("Kafka is temporarily unavailable; durable outboxes retain pending events."); }
    }
}
