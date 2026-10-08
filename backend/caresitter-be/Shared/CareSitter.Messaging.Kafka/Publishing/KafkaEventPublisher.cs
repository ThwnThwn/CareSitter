using System.Text;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Observability;
using Confluent.Kafka;

namespace CareSitter.Messaging.Kafka.Publishing;

/// <summary>A singleton publisher whose acknowledgement is the outbox completion boundary.</summary>
public sealed class KafkaEventPublisher(IProducer<string, string> producer, IEventSerializer serializer,
    KafkaOptions options, MessagingMetrics metrics) : IEventPublisher, IDisposable
{
    /// <summary>Publishes a registered envelope with trace headers and a finite delivery deadline.</summary>
    public async Task<PublishResult> PublishAsync(EventEnvelope envelope, CancellationToken ct = default)
    {
        string json;
        try { json = serializer.Serialize(envelope); }
        catch (Exception ex) when (ex is InvalidDataException or System.Text.Json.JsonException)
        { throw new EventPublishException(PublishFailureKind.MessageError, "Envelope validation failed.", ex); }
        var headers = new Headers();
        AddHeader(headers, "event-id", envelope.EventId.ToString());
        AddHeader(headers, "event-type", envelope.EventType);
        AddHeader(headers, "schema-version", envelope.SchemaVersion.ToString());
        if (envelope.CorrelationId is { } correlation) AddHeader(headers, "correlation-id", correlation);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(options.DeliveryTimeoutMs);
        try
        {
            var result = await producer.ProduceAsync(serializer.GetTopic(envelope),
                new Message<string, string> { Key = envelope.Key, Value = json, Headers = headers }, timeout.Token);
            if (result.Status != PersistenceStatus.Persisted)
                throw new IOException("Kafka did not confirm durable acceptance.");
            return new(envelope.EventId, result.Topic, result.Partition.Value, result.Offset.Value);
        }
        catch (ProduceException<string, string> ex)
        {
            metrics.PublishFailure.Add(1);
            var kind = ex.Error.Code == ErrorCode.MsgSizeTooLarge ? PublishFailureKind.MessageError :
                ex.Error.IsFatal || ex.Error.Code is ErrorCode.TopicAuthorizationFailed or ErrorCode.UnknownTopicOrPart
                    ? PublishFailureKind.ConfigurationError : PublishFailureKind.TransientError;
            throw new EventPublishException(kind, "Kafka delivery failed.", ex);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            metrics.PublishFailure.Add(1);
            throw new EventPublishException(PublishFailureKind.TransientError, "Delivery acknowledgement is uncertain.", ex);
        }
    }

    /// <summary>Adds a UTF-8 transport header without serializing sensitive payloads into logs.</summary>
    internal static void AddHeader(Headers headers, string key, string value) => headers.Add(key, Encoding.UTF8.GetBytes(value));

    /// <summary>Bounds draining during host disposal; unresolved events remain in their outboxes.</summary>
    public void Dispose() => producer.Flush(TimeSpan.FromMilliseconds(options.ShutdownTimeoutMs));
}
