using System.Text.Json;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Kafka.Serialization;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Messaging.Kafka.Consuming;

/// <summary>Validates transport data and invokes application code inside an independent DI scope.</summary>
public sealed class EventDispatcher(IEventSerializer serializer, EventTypeRegistry registry, IServiceScopeFactory scopes)
{
    /// <summary>Dispatches a supported message. Handlers must honor cancellation and own idempotency.</summary>
    public async Task<DispatchResult> DispatchAsync(string json, string topic, int partition, long offset,
        ConsumerRegistration consumer, CancellationToken ct)
    {
        try
        {
            var envelope = serializer.Deserialize(json);
            var entry = registry.Get(envelope.EventType, envelope.SchemaVersion);
            if (entry.Topic != topic) return new(HandlerResult.Permanent("Event received on the wrong topic."), consumer.UnknownMessagePolicy);
            if (!consumer.Handlers.TryGetValue(entry.PayloadType, out var handler))
                return new(HandlerResult.Permanent("No handler registered for this event."), consumer.UnknownMessagePolicy);
            var payload = envelope.Payload.Deserialize(entry.PayloadType, JsonEventSerializer.JsonOptions)
                ?? throw new InvalidDataException("The event payload is null.");
            await using var scope = scopes.CreateAsyncScope();
            var context = new EventContext(envelope.EventId, envelope.EventType, envelope.SchemaVersion,
                consumer.Group, topic, partition, offset, envelope.CorrelationId);
            try
            {
                var result = await handler.Invoke(scope.ServiceProvider, payload, context, ct);
                return new(result, handler.PoisonPolicy, envelope.EventId, envelope.CorrelationId);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                return new(HandlerResult.Transient("Handler deadline expired."), handler.PoisonPolicy,
                    envelope.EventId, envelope.CorrelationId);
            }
            catch (Exception ex)
            {
                return new(HandlerResult.Transient(ex.GetType().Name), handler.PoisonPolicy,
                    envelope.EventId, envelope.CorrelationId);
            }
        }
        catch (Exception e) when (e is JsonException or InvalidDataException or ArgumentException)
        {
            return new(HandlerResult.Permanent(e.GetType().Name), consumer.UnknownMessagePolicy);
        }
    }
}

/// <summary>The dispatch result together with poison policy and safe correlation metadata.</summary>
public sealed record DispatchResult(HandlerResult Result, PoisonPolicy PoisonPolicy,
    Guid? EventId = null, string? CorrelationId = null);
