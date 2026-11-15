using CareSitter.Messaging.Contracts;

namespace CareSitter.Messaging.Abstractions;

/// <summary>Creates, validates and serializes envelopes using the registered event catalog.</summary>
public interface IEventSerializer
{
    /// <summary>Creates a wire envelope with caller-owned identity and occurrence time.</summary>
    EventEnvelope Create<TEvent>(TEvent message, EventMetadata metadata);
    /// <summary>Validates and serializes a complete envelope.</summary>
    string Serialize(EventEnvelope envelope);
    /// <summary>Parses a registered and supported wire message.</summary>
    EventEnvelope Deserialize(string json);
    /// <summary>Returns the registered destination for the envelope.</summary>
    string GetTopic(EventEnvelope envelope);
}
