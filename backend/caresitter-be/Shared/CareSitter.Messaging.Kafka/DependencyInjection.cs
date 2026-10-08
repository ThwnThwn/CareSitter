using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Consuming;
using CareSitter.Messaging.Kafka.Failures;
using CareSitter.Messaging.Kafka.Observability;
using CareSitter.Messaging.Kafka.Publishing;
using CareSitter.Messaging.Kafka.Serialization;
using Confluent.Kafka;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Messaging.Kafka;

/// <summary>Registers the transport once per host, with explicit catalogs and environment validation.</summary>
public static class DependencyInjection
{
    /// <summary>Registers catalog/serialization even when disabled; broker clients exist only when enabled.</summary>
    public static IServiceCollection AddKafkaMessaging(this IServiceCollection services, IConfiguration configuration,
        Action<EventTypeRegistry, KafkaOptions> configure)
    {
        var options = KafkaOptions.Read(configuration);
        var validator = new KafkaOptionsValidator();
        var validation = validator.Validate(null, options);
        if (validation.Failed) throw new OptionsValidationException(nameof(KafkaOptions), typeof(KafkaOptions), validation.Failures);
        services.AddSingleton<IValidateOptions<KafkaOptions>>(validator);
        services.AddOptions<KafkaOptions>().Configure(o => Copy(options, o)).ValidateOnStart();
        services.AddSingleton(options);
        services.AddSingleton(new MessagingSettings(options.Enabled, options.NotificationsEnabled,
            options.PaymentsEnabled, options.NutritionEnabled, options.ClientId));
        var registry = new EventTypeRegistry();
        configure(registry, options);
        services.AddSingleton(registry);
        services.AddSingleton<IEventSerializer, JsonEventSerializer>();
        if (!options.Enabled) return services;
        services.AddSingleton<MessagingMetrics>();
        services.AddSingleton<IProducer<string, string>>(_ => new ProducerBuilder<string, string>(new ProducerConfig
        {
            BootstrapServers = options.BootstrapServers, ClientId = options.ClientId,
            EnableIdempotence = true, Acks = Acks.All, MessageTimeoutMs = options.DeliveryTimeoutMs,
            LingerMs = 5, CompressionType = CompressionType.Lz4,
            MessageMaxBytes = options.MaxMessageBytes + 8192
        }).Build());
        services.AddSingleton<IEventPublisher, KafkaEventPublisher>();
        services.AddSingleton<EventDispatcher>();
        services.AddSingleton<ConsumerRetryPolicy>();
        services.AddSingleton<DeadLetterPublisher>();
        services.AddHealthChecks().AddCheck<KafkaHealthCheck>("kafka", tags: ["ready"]);
        return services;
    }

    /// <summary>Adds an independent consumer group with explicit handlers and topic subscriptions.</summary>
    public static IServiceCollection AddKafkaConsumer(this IServiceCollection services, string group,
        Action<ConsumerRegistration> configure)
    {
        var options = services.FirstOrDefault(x => x.ServiceType == typeof(KafkaOptions))?.ImplementationInstance as KafkaOptions
            ?? throw new InvalidOperationException("Register AddKafkaMessaging before consumers.");
        if (!options.Enabled) return services;
        var consumer = new ConsumerRegistration(group);
        configure(consumer);
        if (string.IsNullOrWhiteSpace(group) || consumer.Topics.Count == 0 || consumer.Topics.Any(x => x.EndsWith(".dlq")))
            throw new InvalidOperationException("A consumer requires a group and non-DLQ subscriptions.");
        services.AddSingleton<IHostedService>(sp => ActivatorUtilities.CreateInstance<KafkaConsumerWorker>(sp, consumer));
        return services;
    }

    /// <summary>Copies validated environment values into the options instance checked at host startup.</summary>
    private static void Copy(KafkaOptions source, KafkaOptions target)
    {
        foreach (var property in typeof(KafkaOptions).GetProperties()) property.SetValue(target, property.GetValue(source));
    }
}
