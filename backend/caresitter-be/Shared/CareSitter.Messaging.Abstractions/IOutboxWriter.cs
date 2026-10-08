using CareSitter.Messaging.Contracts;

namespace CareSitter.Messaging.Abstractions;

/// <summary>Adds messages to the owning unit of work without saving or starting a transaction.</summary>
public interface IOutboxWriter
{
    /// <summary>Stages a message to be committed with the caller's business changes.</summary>
    void Add(EventEnvelope envelope);
}
