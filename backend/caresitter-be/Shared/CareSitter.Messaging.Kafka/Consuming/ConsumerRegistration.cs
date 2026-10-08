using CareSitter.Messaging.Abstractions;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Messaging.Kafka.Consuming;

/// <summary>One consumer group with explicit subscriptions and scoped application handlers.</summary>
public sealed class ConsumerRegistration(string group)
{
    public string Group { get; } = group;
    public HashSet<string> Topics { get; } = [];
    internal Dictionary<Type, HandlerRegistration> Handlers { get; } = [];
    public PoisonPolicy UnknownMessagePolicy { get; set; } = PoisonPolicy.Skip;

    /// <summary>Adds a topic that already exists; consumers never create topics implicitly.</summary>
    public ConsumerRegistration Subscribe(string topic) { Topics.Add(topic); return this; }

    /// <summary>Registers one scoped handler per payload type in this consumer group.</summary>
    public void AddHandler<TEvent, THandler>(IServiceCollection services, PoisonPolicy onPoison = PoisonPolicy.Skip)
        where THandler : class, IEventHandler<TEvent>
    {
        services.AddScoped<THandler>();
        if (!Handlers.TryAdd(typeof(TEvent), new(typeof(THandler).FullName!, onPoison,
            (sp, value, context, ct) => sp.GetRequiredService<THandler>().HandleAsync((TEvent)value, context, ct))))
            throw new InvalidOperationException("A group can register only one handler for a payload type.");
    }
}

internal sealed record HandlerRegistration(string Name, PoisonPolicy PoisonPolicy,
    Func<IServiceProvider, object, EventContext, CancellationToken, Task<HandlerResult>> Invoke);
