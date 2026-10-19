using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using CareSitter.Messaging.Kafka.Serialization;
using CareSitter.ApiHost.Security;
using CareSitter.Contracts.Services;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.Messaging.Kafka;
using CareSitter.Messaging.Persistence;
using CareSitter.Messaging.Persistence.Outbox;
using CareSitter.Modules.Support;
using CareSitter.Modules.Support.Application.Ports;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.NotificationWorker.Application.Commands.Notifications.DeliverNotification;
using CareSitter.NotificationWorker.Application.Ports;
using CareSitter.NotificationWorker.Infrastructure.Clients;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Messaging.Kafka.Configuration;
using Confluent.Kafka;

namespace CareSitter.Messaging.Tests;

[Trait("Category", "MessagingDocker")]
public sealed class NotificationEndToEndTests(MessagingFixture fixture) : IClassFixture<MessagingFixture>
{
    [Fact]
    public async Task Real_support_api_outbox_kafka_worker_claim_and_completion_are_idempotent_and_authenticated()
    {
        var connection = await CreateDatabase();
        await using (var db = SupportDatabase(connection)) await db.Database.EnsureCreatedAsync();
        var topic = await fixture.CreateTopicAsync();
        var key = new string('k', 48);
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["KAFKA_ENABLED"] = "true", ["KAFKA_FLOW_NOTIFICATIONS_ENABLED"] = "true",
            ["KAFKA_BOOTSTRAP_SERVERS"] = fixture.Kafka.GetBootstrapAddress(), ["KAFKA_TOPIC_NOTIFICATIONS"] = topic,
            ["KAFKA_OUTBOX_POLL_INTERVAL_MS"] = "100", ["KAFKA_INTERNAL_SERVICE_KEY"] = key
        }).Build();
        using var server = new TestServer(new WebHostBuilder().ConfigureServices(s =>
        {
            s.AddSingleton<IConfiguration>(config);
            s.AddDbContext<SupportDbContext>(o => o.UseNpgsql(connection));
            s.AddKafkaMessaging(config, (r, o) => r.Add<NotificationRequested>("caresitter.notifications.requested", 1, o.NotificationsTopic));
            s.AddModuleOutbox<SupportDbContext>(config, "support", true);
            s.AddScoped<INotificationDeliveryStore, NotificationDeliveryStore>();
            s.AddSingleton<INotificationRecipientReader, FakeRecipientReader>();
            s.AddSingleton<IPushNotificationService, LegacyPush>();
            s.AddScoped<IUserNotificationService, UserNotificationService>();
            s.AddMediatR(m => m.RegisterServicesFromAssemblyContaining<SupportModule>());
            s.AddAuthentication("MessagingService").AddScheme<AuthenticationSchemeOptions, MessagingServiceAuthenticationHandler>("MessagingService", _ => { });
            s.AddAuthorization();
            s.AddControllers().AddApplicationPart(typeof(SupportModule).Assembly);
        }).Configure(app =>
        {
            app.UseRouting(); app.UseAuthentication(); app.UseAuthorization();
            app.UseEndpoints(e => e.MapControllers());
        }));
        using var http = server.CreateClient();
        var eventId = Guid.NewGuid();
        var recipient = Guid.NewGuid();
        using var unauthorized = await http.PostAsJsonAsync("internal/messaging/notifications/claim",
            new { eventId, notificationId = Guid.NewGuid(), recipientId = recipient, channel = "push" });
        Assert.Equal(HttpStatusCode.Unauthorized, unauthorized.StatusCode);
        http.DefaultRequestHeaders.Add("X-Messaging-Service-Key", key);
        var sender = new RecordingSender();
        using var consumerHost = new HostBuilder().ConfigureServices(s =>
        {
            s.AddKafkaMessaging(config, (r, o) => r.Add<NotificationRequested>("caresitter.notifications.requested", 1, o.NotificationsTopic));
            s.AddSingleton<INotificationDeliveryClient>(new SupportNotificationClient(http));
            s.AddSingleton<INotificationSender>(sender);
            s.AddKafkaConsumer(Guid.NewGuid().ToString(), c =>
            { c.Subscribe(topic); c.AddHandler<NotificationRequested, DeliverNotificationHandler>(s); });
        }).Build();
        await consumerHost.StartAsync();
        await using (var scope = server.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<IUserNotificationService>().NotifyAsync(new UserNotificationMessage(
                recipient, "SYSTEM", "Private message", "Private body", EventId: eventId));
        await using (var scope = server.Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<IUserNotificationService>().NotifyAsync(new UserNotificationMessage(
                recipient, "SYSTEM", "Private message", "Private body", EventId: eventId));
        await WaitUntil(async () =>
        {
            await using var db = SupportDatabase(connection);
            return await db.Set<CareSitter.Modules.Support.Domain.NotificationDelivery>().AnyAsync(x => x.EventId == eventId && x.Status == "Sent");
        });
        Assert.Equal(1, sender.Count);
        Assert.Equal("Private message", sender.LastTitle);
        await using (var db = SupportDatabase(connection))
        {
            Assert.Single(await db.Notifications.ToArrayAsync());
            var row = await db.Set<KafkaOutboxMessage>().SingleAsync(x => x.Id == eventId);
            Assert.DoesNotContain("Private body", row.Envelope);
            Assert.DoesNotContain("token", row.Envelope);
            var serializer = consumerHost.Services.GetRequiredService<IEventSerializer>();
            await consumerHost.Services.GetRequiredService<IEventPublisher>().PublishAsync(serializer.Deserialize(row.Envelope));
            await consumerHost.Services.GetRequiredService<IEventPublisher>().PublishAsync(serializer.Deserialize(row.Envelope));
            var payload = serializer.Deserialize(row.Envelope).Payload.Deserialize<NotificationRequested>(JsonEventSerializer.JsonOptions);
            using var duplicate = await http.PostAsJsonAsync("internal/messaging/notifications/claim",
                new { eventId, notificationId = payload!.NotificationId, recipientId = recipient, channel = "push" });
            Assert.Equal("Sent", (await duplicate.Content.ReadFromJsonAsync<DeliveryClaim>())!.Status);
        }
        await consumerHost.StopAsync();
        Assert.Equal(1, sender.Count);
        Assert.Equal(0, server.Services.GetRequiredService<IPushNotificationService>() is LegacyPush old ? old.Count : -1);
    }

    [Fact]
    public async Task Payment_outbox_failure_rolls_back_finalization_and_the_legacy_outbox()
    {
        var connection = await CreateDatabase();
        await using var db = new PaymentsDbContext(new DbContextOptionsBuilder<PaymentsDbContext>().UseNpgsql(connection).Options);
        await db.Database.EnsureCreatedAsync();
        var intent = PaymentIntent.Create(Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 100000, Guid.NewGuid().ToString()).Value;
        intent.MarkPending(); db.PaymentIntents.Add(intent); await db.SaveChangesAsync();
        // Missing catalog registration fails while the owning business transaction is still open.
        var serializer = new JsonEventSerializer(new EventTypeRegistry(), new KafkaOptions());
        var service = new PaymentFinalizationService(db, new LegacyPaymentDispatcher(), new AuditStub(),
            NullLogger<PaymentFinalizationService>.Instance, new MessagingSettings(true, false, true, false, "test"),
            serializer, new OutboxWriter<PaymentsDbContext>(db, serializer));
        await Assert.ThrowsAsync<InvalidDataException>(() => service.FinalizeSuccessfulPaymentAsync(intent.Id, "test-txn", "{}", PaymentFinalizationSource.Ipn));
        db.ChangeTracker.Clear();
        Assert.Equal("PENDING", (await db.PaymentIntents.SingleAsync()).Status);
        Assert.Empty(await db.LedgerEntries.ToArrayAsync());
        Assert.Empty(await db.OutboxMessages.ToArrayAsync());
        Assert.Empty(await db.Set<KafkaOutboxMessage>().ToArrayAsync());
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Payment_flag_controls_kafka_publication_without_replacing_legacy_dispatch(bool enabled)
    {
        var connection = await CreateDatabase();
        var topic = await fixture.CreateTopicAsync();
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["KAFKA_ENABLED"] = "true", ["KAFKA_FLOW_PAYMENTS_ENABLED"] = enabled.ToString(),
            ["KAFKA_BOOTSTRAP_SERVERS"] = fixture.Kafka.GetBootstrapAddress(), ["KAFKA_TOPIC_PAYMENTS"] = topic,
            ["KAFKA_OUTBOX_POLL_INTERVAL_MS"] = "100"
        }).Build();
        using var host = new HostBuilder().ConfigureServices(s =>
        {
            s.AddDbContext<PaymentsDbContext>(o => o.UseNpgsql(connection));
            s.AddKafkaMessaging(config, (r, o) => r.Add<PaymentSucceeded>("caresitter.payments.succeeded", 1, o.PaymentsTopic));
            s.AddModuleOutbox<PaymentsDbContext>(config, "payments", true);
        }).Build();
        Guid intentId; Guid bookingId;
        var legacy = new LegacyPaymentDispatcher();
        await using (var scope = host.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<PaymentsDbContext>();
            await db.Database.EnsureCreatedAsync();
            var intent = PaymentIntent.Create(Guid.NewGuid(), Guid.NewGuid(), "VNPAY", 100000, Guid.NewGuid().ToString()).Value;
            intent.MarkPending(); db.PaymentIntents.Add(intent); await db.SaveChangesAsync();
            intentId = intent.Id; bookingId = intent.BookingId;
            var service = new PaymentFinalizationService(db, legacy, new AuditStub(), NullLogger<PaymentFinalizationService>.Instance,
                scope.ServiceProvider.GetRequiredService<MessagingSettings>(), scope.ServiceProvider.GetRequiredService<IEventSerializer>(),
                scope.ServiceProvider.GetRequiredService<OutboxWriter<PaymentsDbContext>>());
            Assert.True((await service.FinalizeSuccessfulPaymentAsync(intentId, "test-txn", "{}", PaymentFinalizationSource.Ipn)).Succeeded);
            Assert.True((await service.FinalizeSuccessfulPaymentAsync(intentId, "test-txn", "{}", PaymentFinalizationSource.Ipn)).Succeeded);
            Assert.Equal(1, legacy.Count);
            Assert.Single(await db.LedgerEntries.ToArrayAsync());
            Assert.Single(await db.OutboxMessages.ToArrayAsync());
            Assert.Equal(enabled ? 1 : 0, await db.Set<KafkaOutboxMessage>().CountAsync());
        }
        await host.StartAsync();
        if (enabled)
        {
            using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
            { BootstrapServers = fixture.Kafka.GetBootstrapAddress(), GroupId = Guid.NewGuid().ToString(), AutoOffsetReset = AutoOffsetReset.Earliest }).Build();
            consumer.Subscribe(topic);
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
            var received = await Task.Run(() => consumer.Consume(timeout.Token));
            var envelope = host.Services.GetRequiredService<IEventSerializer>().Deserialize(received.Message.Value);
            var payload = envelope.Payload.Deserialize<PaymentSucceeded>(JsonEventSerializer.JsonOptions)!;
            Assert.Equal(intentId, payload.PaymentIntentId); Assert.Equal(bookingId, payload.BookingId);
            await WaitUntil(async () =>
            {
                await using var db = new PaymentsDbContext(new DbContextOptionsBuilder<PaymentsDbContext>().UseNpgsql(connection).Options);
                return await db.Set<KafkaOutboxMessage>().AllAsync(x => x.PublishedAt != null);
            });
            await using var verify = new PaymentsDbContext(new DbContextOptionsBuilder<PaymentsDbContext>().UseNpgsql(connection).Options);
            Assert.Null((await verify.OutboxMessages.SingleAsync()).ProcessedOnUtc);
        }
        await host.StopAsync();
    }

    [Fact]
    public async Task Numbered_sql_migration_is_repeatable_and_matches_runtime_delivery_mapping()
    {
        var connection = await CreateDatabase();
        await using var db = SupportDatabase(connection);
        await db.Database.EnsureCreatedAsync();
        await db.Database.ExecuteSqlRawAsync("""
            DROP TABLE support.notification_deliveries;
            DROP TABLE support.kafka_outbox_messages;
            DROP TABLE IF EXISTS support.kafka_inbox_messages;
            CREATE SCHEMA payments;
            """);
        var sql = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "34-kafka-messaging.sql"));
        await db.Database.ExecuteSqlRawAsync(sql);
        await db.Database.ExecuteSqlRawAsync(sql);
        Assert.Empty(await db.Set<KafkaOutboxMessage>().ToArrayAsync());
        Assert.Empty(await db.Set<CareSitter.Modules.Support.Domain.NotificationDelivery>().ToArrayAsync());
        await using var raw = new NpgsqlConnection(connection);
        await raw.OpenAsync();
        await using var check = new NpgsqlCommand("SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('support', 'payments') AND table_name IN ('kafka_outbox_messages', 'kafka_inbox_messages', 'notification_deliveries')", raw);
        Assert.Equal(5L, await check.ExecuteScalarAsync());
    }

    [Fact]
    public async Task Disabled_notification_flow_uses_the_legacy_sender_without_creating_outbox()
    {
        var connection = await CreateDatabase();
        await using var db = SupportDatabase(connection);
        await db.Database.EnsureCreatedAsync();
        var sender = new LegacyPush();
        var service = new UserNotificationService(db, sender, NullLogger<UserNotificationService>.Instance,
            new MessagingSettings(false, false, false, false, "test"));
        var eventId = Guid.NewGuid();
        var message = new UserNotificationMessage(
            Guid.NewGuid(), "SYSTEM", "Fallback", EventId: eventId);
        await service.NotifyAsync(message);
        await service.NotifyAsync(message);
        Assert.Equal(1, sender.Count);
        Assert.Empty(await db.Set<KafkaOutboxMessage>().ToArrayAsync());
        Assert.Single(await db.Notifications.ToArrayAsync());
        Assert.Single(await db.Set<CareSitter.Modules.Support.Domain.NotificationDelivery>()
            .Where(x => x.EventId == eventId && x.Status == "Sent").ToArrayAsync());
    }

    [Fact]
    public async Task Disabled_notification_flow_keeps_failed_push_retryable()
    {
        var connection = await CreateDatabase();
        await using var db = SupportDatabase(connection);
        await db.Database.EnsureCreatedAsync();
        var service = new UserNotificationService(db, new FailingPush(),
            NullLogger<UserNotificationService>.Instance,
            new MessagingSettings(false, false, false, false, "test"));
        var eventId = Guid.NewGuid();

        await Assert.ThrowsAsync<TimeoutException>(() => service.NotifyAsync(
            new UserNotificationMessage(Guid.NewGuid(), "BOOKING_CHAT", "Fallback",
                EventId: eventId)));

        db.ChangeTracker.Clear();
        var delivery = await db.Set<CareSitter.Modules.Support.Domain.NotificationDelivery>()
            .SingleAsync(x => x.EventId == eventId);
        Assert.Equal("Failed", delivery.Status);
        Assert.Null(delivery.LeaseUntil);
        Assert.Equal(nameof(TimeoutException), delivery.LastError);
    }

    private SupportDbContext SupportDatabase(string connection) => new(new DbContextOptionsBuilder<SupportDbContext>().UseNpgsql(connection).Options);
    private async Task<string> CreateDatabase()
    {
        var name = "notification_test_" + Guid.NewGuid().ToString("N");
        await using var connection = new NpgsqlConnection(fixture.Postgres.GetConnectionString());
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"CREATE DATABASE \"{name}\"", connection);
        await command.ExecuteNonQueryAsync();
        return new NpgsqlConnectionStringBuilder(fixture.Postgres.GetConnectionString()) { Database = name }.ConnectionString;
    }
    private static async Task WaitUntil(Func<Task<bool>> condition)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(60));
        while (!await condition()) await Task.Delay(100, timeout.Token);
    }
    private sealed class FakeRecipientReader : INotificationRecipientReader
    {
        public Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct) => Task.FromResult(new NotificationRecipient("test@example.invalid", ["token"]));
    }
    private sealed class LegacyPush : IPushNotificationService
    {
        public int Count;
        public Task SendToUserAsync(UserNotificationMessage message, CancellationToken ct = default) { Count++; return Task.CompletedTask; }
    }
    private sealed class FailingPush : IPushNotificationService
    {
        public Task SendToUserAsync(UserNotificationMessage message,
            CancellationToken ct = default) =>
            Task.FromException(new TimeoutException("Injected push failure."));
    }
    private sealed class RecordingSender : INotificationSender
    {
        public int Count;
        public string? LastTitle;
        public Task<HandlerResult> SendAsync(string channel, DeliveryClaim claim, CancellationToken ct)
        { Interlocked.Increment(ref Count); LastTitle = claim.Title; return Task.FromResult(HandlerResult.Success()); }
    }
    private sealed class LegacyPaymentDispatcher : IPaymentOutboxDispatcher
    {
        public int Count;
        public Task DispatchAsync(Guid messageId, CancellationToken ct = default) { Count++; return Task.CompletedTask; }
        public Task<int> DispatchPendingAsync(int batchSize = 20, CancellationToken ct = default) => Task.FromResult(0);
    }
    private sealed class AuditStub : IAuditLogger
    {
        public Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after, CancellationToken ct = default) => Task.CompletedTask;
    }
}
