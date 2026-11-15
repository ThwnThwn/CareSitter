using System.Text;
using System.Text.Json;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Kafka.Configuration;

namespace CareSitter.Messaging.Kafka.Serialization;

/// <summary>Enforces a bounded, camel-case JSON envelope against the explicit event catalog.</summary>
public sealed class JsonEventSerializer(EventTypeRegistry registry, KafkaOptions options) : IEventSerializer
{
    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web) { MaxDepth = 32 };

    /// <summary>Creates a message using caller-supplied metadata and a registered payload type.</summary>
    public EventEnvelope Create<TEvent>(TEvent message, EventMetadata metadata)
    {
        var entry = registry.Get(typeof(TEvent));
        var envelope = new EventEnvelope(metadata.EventId, entry.EventType, entry.Version, metadata.OccurredAt,
            metadata.Producer, metadata.CorrelationId, metadata.Key, JsonSerializer.SerializeToElement(message, JsonOptions));
        Serialize(envelope);
        return envelope;
    }

    /// <summary>Validates metadata and size before the envelope enters an outbox or producer buffer.</summary>
    public string Serialize(EventEnvelope envelope)
    {
        Validate(envelope);
        var json = JsonSerializer.Serialize(envelope, JsonOptions);
        ValidateSize(json);
        return json;
    }

    /// <summary>Rejects malformed JSON and unknown versions while accepting optional future fields.</summary>
    public EventEnvelope Deserialize(string json)
    {
        ValidateSize(json);
        var envelope = JsonSerializer.Deserialize<EventEnvelope>(json, JsonOptions)
            ?? throw new InvalidDataException("The event envelope is null.");
        Validate(envelope);
        return envelope;
    }

    /// <summary>Resolves the registered destination without accepting a caller-selected topic.</summary>
    public string GetTopic(EventEnvelope envelope) => registry.Get(envelope.EventType, envelope.SchemaVersion).Topic;

    /// <summary>Checks transport metadata and resolves only explicitly registered wire identities.</summary>
    private void Validate(EventEnvelope e)
    {
        if (e.EventId == Guid.Empty || e.OccurredAt == default || e.OccurredAt.Offset != TimeSpan.Zero ||
            string.IsNullOrWhiteSpace(e.Producer) || string.IsNullOrWhiteSpace(e.Key) ||
            e.Producer.Length > 128 || e.Key.Length > 256 || e.CorrelationId?.Length > 256 ||
            e.Payload.ValueKind != JsonValueKind.Object)
            throw new InvalidDataException("The envelope requires identity, UTC time, bounded producer/key and an object payload.");
        registry.Get(e.EventType, e.SchemaVersion);
    }

    /// <summary>Bounds UTF-8 wire size before deserialization or buffering.</summary>
    private void ValidateSize(string json)
    {
        if (Encoding.UTF8.GetByteCount(json) > options.MaxMessageBytes)
            throw new InvalidDataException("The event exceeds KAFKA_PRODUCER_MAX_MESSAGE_BYTES.");
    }
}
