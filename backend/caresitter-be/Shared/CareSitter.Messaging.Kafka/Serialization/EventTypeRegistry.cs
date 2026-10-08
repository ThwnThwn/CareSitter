namespace CareSitter.Messaging.Kafka.Serialization;

/// <summary>An explicit allowlist of stable network names, versions, CLR payloads and destinations.</summary>
public sealed class EventTypeRegistry
{
    private readonly Dictionary<(string, int), EventRegistration> _events = [];

    /// <summary>Registers a unique wire identity. Registration happens before the host is built.</summary>
    public void Add<T>(string eventType, int version, string topic)
    {
        if (string.IsNullOrWhiteSpace(eventType) || version < 1 || string.IsNullOrWhiteSpace(topic))
            throw new ArgumentException("Event type, positive version and topic are required.");
        if (!_events.TryAdd((eventType, version), new(eventType, version, typeof(T), topic)))
            throw new InvalidOperationException($"Duplicate event registration: {eventType} v{version}.");
    }

    /// <summary>Resolves a supported wire identity; never loads a CLR type from untrusted input.</summary>
    public EventRegistration Get(string eventType, int version) => _events.TryGetValue((eventType, version), out var entry)
        ? entry : throw new InvalidDataException($"Unsupported event type/version: {eventType} v{version}.");

    /// <summary>Resolves a payload type for writing; multiple versions require explicit creation.</summary>
    public EventRegistration Get(Type type) => _events.Values.SingleOrDefault(x => x.PayloadType == type)
        ?? throw new InvalidDataException($"Payload type is not registered: {type.Name}.");
}

/// <summary>A catalog entry describing one version of a network event.</summary>
public sealed record EventRegistration(string EventType, int Version, Type PayloadType, string Topic);
