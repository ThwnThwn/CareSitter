using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Observability;
using CareSitter.Messaging.Kafka.Publishing;
using Confluent.Kafka;

namespace CareSitter.Messaging.Kafka.Failures;

/// <summary>Quarantines original wire data before the source offset may advance.</summary>
public sealed class DeadLetterPublisher(IProducer<string, string> producer, KafkaOptions options, MessagingMetrics metrics)
{
    /// <summary>Preserves original bytes and trace headers; unknown envelopes remain inspectable.</summary>
    public async Task PublishAsync(ConsumeResult<string, string> source, string consumer, string reason, int attempts, CancellationToken ct)
    {
        var headers = new Headers();
        foreach (var h in source.Message.Headers ?? new Headers()) headers.Add(h.Key, h.GetValueBytes());
        KafkaEventPublisher.AddHeader(headers, "source-topic", source.Topic);
        KafkaEventPublisher.AddHeader(headers, "source-partition", source.Partition.Value.ToString());
        KafkaEventPublisher.AddHeader(headers, "source-offset", source.Offset.Value.ToString());
        KafkaEventPublisher.AddHeader(headers, "consumer-name", consumer);
        KafkaEventPublisher.AddHeader(headers, "error", reason[..Math.Min(reason.Length, 512)]);
        KafkaEventPublisher.AddHeader(headers, "attempt-count", attempts.ToString());
        KafkaEventPublisher.AddHeader(headers, "failed-at", DateTimeOffset.UtcNow.ToString("O"));
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(options.DeliveryTimeoutMs);
        var result = await producer.ProduceAsync(options.GetDeadLetterTopic(source.Topic),
            new Message<string, string> { Key = source.Message.Key, Value = source.Message.Value, Headers = headers }, timeout.Token);
        if (result.Status != PersistenceStatus.Persisted) throw new IOException("DLQ acknowledgement is uncertain.");
        metrics.DeadLetters.Add(1);
    }
}
