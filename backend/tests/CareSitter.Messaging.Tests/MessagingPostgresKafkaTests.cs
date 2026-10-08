using System.Collections.Concurrent;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Kafka;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Observability;
using CareSitter.Messaging.Kafka.Publishing;
using CareSitter.Messaging.Persistence;
using CareSitter.Messaging.Persistence.Inbox;
using CareSitter.Messaging.Persistence.Outbox;
using Confluent.Kafka;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CareSitter.Messaging.Tests;

[Trait("Category", "MessagingDocker")]
public sealed class MessagingPostgresKafkaTests(MessagingFixture fixture) : IClassFixture<MessagingFixture>
{
    private MessagingDbContext Database() => new(new DbContextOptionsBuilder<MessagingDbContext>()
        .UseNpgsql(fixture.Postgres.GetConnectionString()).Options);

    [Fact]
    public async Task Rollback_claim_lease_recovery_and_owner_fencing_are_atomic()
    {
        await using var db = Database();
        await db.Database.EnsureCreatedAsync();
        var id = Guid.NewGuid();
        await using (var tx = await db.Database.BeginTransactionAsync())
        {
            db.Outbox.Add(Row(id));
            await db.SaveChangesAsync();
            await tx.RollbackAsync();
        }
        db.ChangeTracker.Clear();
        Assert.False(await db.Outbox.AnyAsync(x => x.Id == id));
        db.Outbox.Add(Row(id));
        await db.SaveChangesAsync();
        var store = new EfOutboxStore<MessagingDbContext>(db, "messaging_test");
        Assert.Contains(await store.ClaimAsync("owner-a", 100, TimeSpan.FromSeconds(60), default), x => x.Id == id);
        Assert.DoesNotContain(await store.ClaimAsync("owner-b", 100, TimeSpan.FromSeconds(60), default), x => x.Id == id);
        await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE messaging_test.kafka_outbox_messages SET lease_until = now() - interval '1 second' WHERE id = {id}");
        Assert.Contains(await store.ClaimAsync("owner-b", 100, TimeSpan.FromSeconds(60), default), x => x.Id == id);
        await store.MarkPublishedAsync(id, "owner-a", default);
        Assert.Null(await db.Outbox.Where(x => x.Id == id).Select(x => x.PublishedAt).SingleAsync());
        await store.MarkPublishedAsync(id, "owner-b", default);
        Assert.NotNull(await db.Outbox.Where(x => x.Id == id).Select(x => x.PublishedAt).SingleAsync());
    }

    [Fact]
    public async Task Inbox_rolls_back_rejections_and_deduplicates_committed_effects()
    {
        await using var db = Database();
        await db.Database.EnsureCreatedAsync();
        var inbox = new EfInboxStore<MessagingDbContext>(db, "messaging_test");
        var context = new EventContext(Guid.NewGuid(), "sample", 1, "test", "topic", 0, 0, null);
        var failed = await inbox.ExecuteAsync(context, "handler", _ =>
        {
            db.Effects.Add(new Effect { Id = Guid.NewGuid(), EventId = context.EventId });
            return Task.FromResult(HandlerResult.Transient("Database dependency failed."));
        }, default);
        Assert.Equal(HandlerOutcome.Transient, failed.Outcome);
        Assert.False(await db.Effects.AnyAsync(x => x.EventId == context.EventId));
        Assert.False(await db.Inbox.AnyAsync(x => x.EventId == context.EventId));
        for (var i = 0; i < 2; i++)
            await inbox.ExecuteAsync(context, "handler", _ =>
            {
                db.Effects.Add(new Effect { Id = Guid.NewGuid(), EventId = context.EventId });
                return Task.FromResult(HandlerResult.Success());
            }, default);
        Assert.Equal(1, await db.Effects.CountAsync(x => x.EventId == context.EventId));
    }

    [Fact]
    public async Task Ack_lost_after_real_publish_is_retried_with_same_id_and_one_database_effect()
    {
        var topic = await fixture.CreateTopicAsync();
        using var host = BuildHost(topic, loseFirstAck: true);
        await using (var scope = host.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<MessagingDbContext>().Database.EnsureCreatedAsync();
        var id = Guid.NewGuid();
        await using (var scope = host.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();
            var serializer = scope.ServiceProvider.GetRequiredService<IEventSerializer>();
            scope.ServiceProvider.GetRequiredService<OutboxWriter<MessagingDbContext>>().Add(serializer.Create(
                new SampleEvent(false, false), new EventMetadata(id, DateTimeOffset.UtcNow, "test", id.ToString())));
            await db.SaveChangesAsync();
        }
        await host.StartAsync();
        await WaitUntil(async () =>
        {
            await using var db = Database();
            return await db.Outbox.AnyAsync(x => x.Id == id && x.PublishedAt != null) &&
                await db.Effects.CountAsync(x => x.EventId == id) == 1;
        });
        await WaitUntil(() => Task.FromResult(host.Services.GetRequiredService<Probe>().Deliveries.GetValueOrDefault(id) >= 2));
        await host.StopAsync();
        await using var verify = Database();
        Assert.Equal(1, await verify.Effects.CountAsync(x => x.EventId == id));
        Assert.True(await verify.Outbox.Where(x => x.Id == id).Select(x => x.AttemptCount >= 2).SingleAsync());
    }

    [Fact]
    public async Task Transient_handler_recovers_and_unknown_version_is_quarantined_with_source_headers()
    {
        var topic = await fixture.CreateTopicAsync();
        using var host = BuildHost(topic);
        await using (var scope = host.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<MessagingDbContext>().Database.EnsureCreatedAsync();
        await host.StartAsync();
        var serializer = host.Services.GetRequiredService<IEventSerializer>();
        var envelope = serializer.Create(new SampleEvent(true, false), new EventMetadata(Guid.NewGuid(), DateTimeOffset.UtcNow, "test", "retry"));
        await host.Services.GetRequiredService<IEventPublisher>().PublishAsync(envelope);
        await WaitUntil(async () => { await using var db = Database(); return await db.Effects.AnyAsync(x => x.EventId == envelope.EventId); });
        var client = host.Services.GetRequiredService<IProducer<string, string>>();
        await client.ProduceAsync(topic, new Message<string, string>
        { Key = "bad", Value = serializer.Serialize(envelope).Replace("\"schemaVersion\":1", "\"schemaVersion\":99") });
        using var dlq = new ConsumerBuilder<string, string>(new ConsumerConfig
        { BootstrapServers = fixture.Kafka.GetBootstrapAddress(), GroupId = Guid.NewGuid().ToString(), AutoOffsetReset = AutoOffsetReset.Earliest }).Build();
        dlq.Subscribe(topic + ".dlq");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        var result = await Task.Run(() => dlq.Consume(timeout.Token));
        Assert.Contains("\"schemaVersion\":99", result.Message.Value);
        Assert.Contains(result.Message.Headers, h => h.Key == "source-offset");
        Assert.Contains(result.Message.Headers, h => h.Key == "consumer-name");
        await host.StopAsync();
        Assert.True(host.Services.GetRequiredService<Probe>().Deliveries[envelope.EventId] >= 2);
    }

    [Fact]
    public async Task Broker_restart_preserves_committed_outbox_and_resumes_publication()
    {
        var topic = await fixture.CreateTopicAsync();
        using var host = BuildHost(topic);
        var id = Guid.NewGuid();
        await using (var scope = host.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();
            await db.Database.EnsureCreatedAsync();
            scope.ServiceProvider.GetRequiredService<OutboxWriter<MessagingDbContext>>().Add(
                scope.ServiceProvider.GetRequiredService<IEventSerializer>().Create(new SampleEvent(false, false),
                    new EventMetadata(id, DateTimeOffset.UtcNow, "test", id.ToString())));
            await db.SaveChangesAsync();
        }
        await fixture.Kafka.StopAsync();
        try
        {
            await host.StartAsync();
            await WaitUntil(async () =>
            {
                await using var db = Database();
                return await db.Outbox.AnyAsync(x => x.Id == id && x.AttemptCount > 0 && x.PublishedAt == null && x.LastError != null);
            });
        }
        finally { await fixture.Kafka.StartAsync(); }
        await WaitUntil(async () =>
        {
            await using var db = Database();
            return await db.Outbox.AnyAsync(x => x.Id == id && x.PublishedAt != null);
        });
        await host.StopAsync();
    }

    [Fact]
    public async Task Failed_dlq_does_not_skip_source_and_halt_policy_keeps_it_uncommitted()
    {
        var topic = await fixture.CreateTopicAsync();
        using var admin = new AdminClientBuilder(new AdminClientConfig { BootstrapServers = fixture.Kafka.GetBootstrapAddress() }).Build();
        await admin.DeleteTopicsAsync([topic + ".dlq"]);
        using var host = BuildHost(topic, poison: PoisonPolicy.Halt);
        await using (var scope = host.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<MessagingDbContext>().Database.EnsureCreatedAsync();
        await host.StartAsync();
        var serializer = host.Services.GetRequiredService<IEventSerializer>();
        var envelope = serializer.Create(new SampleEvent(false, true), new EventMetadata(Guid.NewGuid(), DateTimeOffset.UtcNow, "test", "poison"));
        await host.Services.GetRequiredService<IEventPublisher>().PublishAsync(envelope);
        await WaitUntil(() => Task.FromResult(host.Services.GetRequiredService<MessagingMetrics>().ConsumerDegraded));
        Assert.False(host.Services.GetRequiredService<MessagingMetrics>().ConsumerHalted);
        await admin.CreateTopicsAsync([new Confluent.Kafka.Admin.TopicSpecification { Name = topic + ".dlq", NumPartitions = 1, ReplicationFactor = 1 }]);
        await WaitUntil(() => Task.FromResult(host.Services.GetRequiredService<MessagingMetrics>().ConsumerHalted));
        Assert.True(host.Services.GetRequiredService<Probe>().Deliveries[envelope.EventId] >= 2);
        await using var db = Database();
        Assert.False(await db.Inbox.AnyAsync(x => x.EventId == envelope.EventId));
        Assert.False(await db.Effects.AnyAsync(x => x.EventId == envelope.EventId));
        await host.StopAsync();
    }

    [Fact]
    public async Task Shutdown_after_database_commit_redelivers_without_a_second_effect()
    {
        var topic = await fixture.CreateTopicAsync();
        var group = Guid.NewGuid().ToString();
        using var first = BuildHost(topic, group: group, interruptAfterCommit: true);
        await using (var scope = first.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<MessagingDbContext>().Database.EnsureCreatedAsync();
        await first.StartAsync();
        var envelope = first.Services.GetRequiredService<IEventSerializer>().Create(new SampleEvent(false, false),
            new EventMetadata(Guid.NewGuid(), DateTimeOffset.UtcNow, "test", "shutdown"));
        await first.Services.GetRequiredService<IEventPublisher>().PublishAsync(envelope);
        await first.Services.GetRequiredService<Probe>().Committed.Task.WaitAsync(TimeSpan.FromSeconds(45));
        // Cancellation occurs after the inbox transaction but before the handler returns to commit offsets.
        await first.StopAsync();
        using var restarted = BuildHost(topic, group: group);
        await restarted.StartAsync();
        await WaitUntil(() => Task.FromResult(restarted.Services.GetRequiredService<Probe>().Deliveries.ContainsKey(envelope.EventId)));
        await restarted.StopAsync();
        await using var db = Database();
        Assert.Equal(1, await db.Effects.CountAsync(x => x.EventId == envelope.EventId));
        Assert.Equal(1, await db.Inbox.CountAsync(x => x.EventId == envelope.EventId));
    }

    [Fact]
    public async Task Two_consumers_share_partitions_and_keep_database_effects_unique()
    {
        var topic = await fixture.CreateTopicAsync();
        var group = Guid.NewGuid().ToString();
        using var first = BuildHost(topic, group: group);
        using var second = BuildHost(topic, group: group);
        await using (var scope = first.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<MessagingDbContext>().Database.EnsureCreatedAsync();
        await Task.WhenAll(first.StartAsync(), second.StartAsync());
        using var admin = new AdminClientBuilder(new AdminClientConfig { BootstrapServers = fixture.Kafka.GetBootstrapAddress() }).Build();
        await WaitUntil(async () =>
        {
            try
            {
                var description = await admin.DescribeConsumerGroupsAsync([group]);
                var members = description.ConsumerGroupDescriptions.Single().Members;
                return members.Count == 2 && members.All(x => x.Assignment.TopicPartitions.Count > 0);
            }
            catch (Confluent.Kafka.Admin.DescribeConsumerGroupsException) { return false; }
        });
        var serializer = first.Services.GetRequiredService<IEventSerializer>();
        var producer = first.Services.GetRequiredService<IProducer<string, string>>();
        var ids = new List<Guid>();
        for (var i = 0; i < 12; i++)
        {
            var id = Guid.NewGuid(); ids.Add(id);
            var envelope = serializer.Create(new SampleEvent(false, false), new EventMetadata(id, DateTimeOffset.UtcNow, "test", id.ToString()));
            await producer.ProduceAsync(new TopicPartition(topic, new Partition(i % 3)),
                new Message<string, string> { Key = envelope.Key, Value = serializer.Serialize(envelope) });
        }
        await WaitUntil(async () => { await using var db = Database(); return await db.Effects.CountAsync(x => ids.Contains(x.EventId)) == ids.Count; });
        Assert.NotEmpty(first.Services.GetRequiredService<Probe>().Deliveries);
        Assert.NotEmpty(second.Services.GetRequiredService<Probe>().Deliveries);
        await Task.WhenAll(first.StopAsync(), second.StopAsync());
        await using var verify = Database();
        Assert.Equal(ids.Count, await verify.Inbox.CountAsync(x => ids.Contains(x.EventId)));
    }

    private IHost BuildHost(string topic, bool loseFirstAck = false, PoisonPolicy poison = PoisonPolicy.Skip,
        string? group = null, bool interruptAfterCommit = false)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["KAFKA_ENABLED"] = "true", ["KAFKA_BOOTSTRAP_SERVERS"] = fixture.Kafka.GetBootstrapAddress(),
            ["KAFKA_OUTBOX_POLL_INTERVAL_MS"] = "100", ["KAFKA_PRODUCER_DELIVERY_TIMEOUT_MS"] = "10000",
            ["KAFKA_CONSUMER_SHUTDOWN_TIMEOUT_MS"] = "1000"
        }).Build();
        return new HostBuilder().ConfigureServices(s =>
        {
            s.AddDbContext<MessagingDbContext>(o => o.UseNpgsql(fixture.Postgres.GetConnectionString()));
            s.AddKafkaMessaging(config, (r, _) => r.Add<SampleEvent>("sample.completed", 1, topic));
            s.AddModuleOutbox<MessagingDbContext>(config, "messaging_test", true);
            s.AddModuleInbox<MessagingDbContext>("messaging_test");
            s.AddSingleton(new Probe { InterruptAfterCommit = interruptAfterCommit });
            s.AddKafkaConsumer(group ?? Guid.NewGuid().ToString(), c => { c.Subscribe(topic); c.AddHandler<SampleEvent, SampleHandler>(s, poison); });
            if (loseFirstAck) s.AddSingleton<IEventPublisher>(sp => new LostAckPublisher(ActivatorUtilities.CreateInstance<KafkaEventPublisher>(sp)));
        }).Build();
    }

    private static async Task WaitUntil(Func<Task<bool>> condition)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(60));
        while (!await condition()) await Task.Delay(100, timeout.Token);
    }

    private static KafkaOutboxMessage Row(Guid id) => new()
    {
        Id = id, EventType = "sample", SchemaVersion = 1, Topic = "topic", MessageKey = "key", Envelope = "{}",
        OccurredAt = DateTimeOffset.UtcNow,
        // Bản ghi test phải đến hạn rõ ràng, không phụ thuộc lệch đồng hồ host/Docker.
        NextAttemptAt = DateTimeOffset.UnixEpoch
    };

    public sealed record SampleEvent(bool FailFirst, bool Permanent);
    public sealed class Probe
    {
        public ConcurrentDictionary<Guid, int> Deliveries { get; } = new();
        public bool InterruptAfterCommit { get; init; }
        public TaskCompletionSource Committed { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    }
    public sealed class SampleHandler(MessagingDbContext db, EfInboxStore<MessagingDbContext> inbox, Probe probe) : IEventHandler<SampleEvent>
    {
        public async Task<HandlerResult> HandleAsync(SampleEvent message, EventContext context, CancellationToken ct)
        {
            var count = probe.Deliveries.AddOrUpdate(context.EventId, 1, (_, n) => n + 1);
            if (message.FailFirst && count == 1) return HandlerResult.Transient("Temporary test failure.");
            var result = await inbox.ExecuteAsync(context, "sample-handler", _ =>
            {
                db.Effects.Add(new Effect { Id = Guid.NewGuid(), EventId = context.EventId });
                return Task.FromResult(message.Permanent ? HandlerResult.Permanent("Rejected.") : HandlerResult.Success());
            }, ct);
            if (probe.InterruptAfterCommit)
            {
                probe.Committed.TrySetResult();
                await Task.Delay(Timeout.InfiniteTimeSpan, ct);
            }
            return result;
        }
    }
    private sealed class LostAckPublisher(KafkaEventPublisher actual) : IEventPublisher, IDisposable
    {
        private int _calls;
        public async Task<PublishResult> PublishAsync(EventEnvelope envelope, CancellationToken ct = default)
        {
            var result = await actual.PublishAsync(envelope, ct);
            if (Interlocked.Increment(ref _calls) == 1) throw new TimeoutException("Simulated lost broker acknowledgement.");
            return result;
        }
        public void Dispose() => actual.Dispose();
    }
    public sealed class Effect { public Guid Id { get; set; } public Guid EventId { get; set; } }
    public sealed class MessagingDbContext(DbContextOptions<MessagingDbContext> options) : DbContext(options)
    {
        public DbSet<KafkaOutboxMessage> Outbox => Set<KafkaOutboxMessage>();
        public DbSet<InboxMessage> Inbox => Set<InboxMessage>();
        public DbSet<Effect> Effects => Set<Effect>();
        protected override void OnModelCreating(ModelBuilder model)
        {
            model.ApplyKafkaOutbox("messaging_test").ApplyKafkaInbox("messaging_test");
            model.Entity<Effect>().ToTable("effects", "messaging_test").HasKey(x => x.Id);
        }
    }
}
