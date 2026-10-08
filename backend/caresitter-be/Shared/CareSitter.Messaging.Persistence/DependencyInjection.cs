using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Persistence.Inbox;
using CareSitter.Messaging.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace CareSitter.Messaging.Persistence;

/// <summary>Registers module-owned persistence while hosting one relay and cleanup worker per process.</summary>
public static class DependencyInjection
{
    /// <summary>Registers a scoped writer/store and host-level relay only when messaging is enabled.</summary>
    public static IServiceCollection AddModuleOutbox<TDbContext>(this IServiceCollection services, IConfiguration config,
        string schema, bool enabled) where TDbContext : DbContext
    {
        OutboxConfiguration.ValidateSchema(schema);
        if (!enabled) return services;
        services.AddScoped<OutboxWriter<TDbContext>>();
        services.AddScoped<IOutboxStore>(sp => new EfOutboxStore<TDbContext>(sp.GetRequiredService<TDbContext>(), schema));
        services.TryAddSingleton(MessagingPersistenceOptions.Read(config));
        services.AddHostedService<OutboxRelayWorker>();
        services.AddHostedService<OutboxCleanupWorker>();
        return services;
    }

    /// <summary>Registers a local inbox store; application effects must use the same scoped DbContext.</summary>
    public static IServiceCollection AddModuleInbox<TDbContext>(this IServiceCollection services, string schema) where TDbContext : DbContext
    {
        services.AddScoped<EfInboxStore<TDbContext>>(sp => new(sp.GetRequiredService<TDbContext>(), schema));
        services.AddScoped<IInboxStore>(sp => sp.GetRequiredService<EfInboxStore<TDbContext>>());
        return services;
    }
}
