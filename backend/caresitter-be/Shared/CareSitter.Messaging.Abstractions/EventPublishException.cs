namespace CareSitter.Messaging.Abstractions;

/// <summary>Classifies publishing failures without coupling the outbox to Kafka client error codes.</summary>
public enum PublishFailureKind { ConfigurationError, MessageError, TransientError }

/// <summary>An acknowledged failure classification. A timeout still permits broker-side acceptance.</summary>
public sealed class EventPublishException(PublishFailureKind kind, string message, Exception? inner = null) : Exception(message, inner)
{
    public PublishFailureKind Kind { get; } = kind;
}
