using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Failures;
using CareSitter.Messaging.Kafka.Observability;
using Confluent.Kafka;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CareSitter.Messaging.Kafka.Consuming;

/// <summary>A sequential consumer with bounded retries, explicit commits and acknowledged quarantine.</summary>
public sealed class KafkaConsumerWorker(KafkaOptions options, ConsumerRegistration registration,
    EventDispatcher dispatcher, ConsumerRetryPolicy retry, DeadLetterPublisher dlq,
    MessagingMetrics metrics, ILogger<KafkaConsumerWorker> logger) : BackgroundService
{
    /// <summary>Consumes one message at a time; incomplete or unquarantined records never advance offsets.</summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Yield();
        while (!stoppingToken.IsCancellationRequested && !metrics.ConsumerHalted)
        {
            using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
            {
                BootstrapServers = options.BootstrapServers, ClientId = options.ClientId,
                GroupId = registration.Group, EnableAutoCommit = false, EnableAutoOffsetStore = false,
                AutoOffsetReset = AutoOffsetReset.Earliest, AllowAutoCreateTopics = false,
                PartitionAssignmentStrategy = PartitionAssignmentStrategy.CooperativeSticky,
                MaxPollIntervalMs = options.MaxPollIntervalMs,
                SocketTimeoutMs = Math.Min(options.DeliveryTimeoutMs, 10000)
            }).SetPartitionsRevokedHandler((_, _) => { /* All commits occur after sequential processing. */ }).Build();
            consumer.Subscribe(registration.Topics);
            try
            {
                while (!stoppingToken.IsCancellationRequested)
                {
                    var source = consumer.Consume(stoppingToken);
                    using var work = new CancellationTokenSource(TimeSpan.FromMilliseconds(options.MaxPollIntervalMs - 5000));
                    using var stopRegistration = stoppingToken.Register(() => work.CancelAfter(options.ShutdownTimeoutMs));
                    var result = new DispatchResult(HandlerResult.Transient("Handler did not run."), registration.UnknownMessagePolicy);
                    var attempts = 0;
                    var attemptCount = 0;
                    for (; attempts <= options.MaxRetries; attempts++)
                    {
                        attemptCount = attempts + 1;
                        using var attempt = CancellationTokenSource.CreateLinkedTokenSource(work.Token);
                        attempt.CancelAfter(options.HandlerTimeoutMs);
                        try
                        {
                            result = await dispatcher.DispatchAsync(source.Message.Value ?? "null", source.Topic,
                                source.Partition.Value, source.Offset.Value, registration, attempt.Token);
                            // Shutdown cancellation must leave unfinished work uncommitted, not send it to DLQ.
                            work.Token.ThrowIfCancellationRequested();
                        }
                        catch (OperationCanceledException) when (work.IsCancellationRequested) { throw; }
                        catch (Exception ex)
                        {
                            result = new(HandlerResult.Transient(ex.GetType().Name), registration.UnknownMessagePolicy);
                        }
                        if (result.Result.Outcome != HandlerOutcome.Transient) break;
                        metrics.HandlerFailure.Add(1);
                        if (attempts < options.MaxRetries) await Task.Delay(retry.Delay(attempts), work.Token);
                    }
                    logger.LogInformation("Event {EventId} correlation {CorrelationId} topic {Topic} partition {Partition} offset {Offset} attempt {Attempt} outcome {Outcome}",
                        result.EventId, result.CorrelationId, source.Topic, source.Partition.Value,
                        source.Offset.Value, attemptCount, result.Result.Outcome);
                    if (result.Result.Outcome != HandlerOutcome.Success)
                    {
                        try
                        {
                            await dlq.PublishAsync(source, registration.Group, result.Result.Reason ?? "Handler failed.", attemptCount, work.Token);
                            metrics.ConsumerDegraded = false;
                        }
                        catch (Exception ex) when (!work.IsCancellationRequested)
                        {
                            metrics.ConsumerDegraded = true;
                            logger.LogCritical("DLQ publish failed at {Topic}/{Partition}/{Offset}: {FailureType}",
                                source.Topic, source.Partition.Value, source.Offset.Value, ex.GetType().Name);
                            // Seek before polling again, so a later message cannot skip this failed delivery.
                            consumer.Seek(source.TopicPartitionOffset);
                            await Task.Delay(retry.Delay(0), stoppingToken);
                            continue;
                        }
                        if (result.PoisonPolicy == PoisonPolicy.Halt)
                        {
                            metrics.ConsumerHalted = true;
                            return; // Keep the source offset uncommitted for an explicit operator decision.
                        }
                    }
                    try
                    {
                        consumer.Commit(source);
                        var watermarks = consumer.GetWatermarkOffsets(source.TopicPartition);
                        metrics.ObserveLag(source.Topic, source.Partition.Value, watermarks.High.Value, source.Offset.Value);
                        metrics.ConsumerDegraded = false;
                    }
                    catch (KafkaException)
                    {
                        metrics.ConsumerDegraded = true;
                        // Acknowledgement uncertainty permits redelivery; inbox/idempotency owns deduplication.
                        break;
                    }
                }
            }
            catch (OperationCanceledException) { if (!stoppingToken.IsCancellationRequested) metrics.ConsumerDegraded = true; }
            catch (KafkaException ex)
            {
                metrics.ConsumerDegraded = true;
                logger.LogWarning("Kafka consumer failure: {Code}", ex.Error.Code);
            }
            finally { consumer.Close(); }
            if (!stoppingToken.IsCancellationRequested) await Task.Delay(retry.Delay(0), stoppingToken);
        }
    }
}
