using System.Text.Json;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Consuming;
using CareSitter.Messaging.Kafka.Serialization;
using CareSitter.Messaging.Persistence;
using CareSitter.Messaging.Persistence.Outbox;
using CareSitter.NotificationWorker.Application.Commands.Notifications.DeliverNotification;
using CareSitter.NotificationWorker.Application.Ports;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Messaging.Tests;

public sealed class MessagingUnitTests
{
    private static JsonEventSerializer Serializer(int size = 65536)
    {
        var registry = new EventTypeRegistry();
        registry.Add<NotificationRequested>("caresitter.notifications.requested", 1, "notifications");
        registry.Add<PaymentSucceeded>("caresitter.payments.succeeded", 1, "payments");
        registry.Add<MealPlanSelected>("caresitter.nutrition.mealplan-selected", 1, "nutrition");
        return new(registry, new KafkaOptions { MaxMessageBytes = size });
    }

    [Fact]
    public void Envelope_uses_stable_names_camel_case_and_accepts_optional_fields()
    {
        var serializer = Serializer();
        var id = Guid.NewGuid();
        var e = serializer.Create(new NotificationRequested(Guid.NewGuid(), Guid.NewGuid(), ["push"], "PAYMENT"),
            new EventMetadata(id, DateTimeOffset.UtcNow, "api", "booking", "trace"));
        var json = serializer.Serialize(e);
        Assert.Contains("\"eventType\":\"caresitter.notifications.requested\"", json);
        Assert.Contains("\"schemaVersion\":1", json);
        Assert.DoesNotContain("CareSitter.Messaging.Contracts.Events", json);
        Assert.Equal(id, serializer.Deserialize(json[..^1] + ",\"futureOptional\":true}").EventId);
        Assert.Throws<InvalidDataException>(() => serializer.Deserialize(json.Replace("\"schemaVersion\":1", "\"schemaVersion\":99")));
    }

    [Fact]
    public async Task All_v1_contracts_match_their_reviewable_json_snapshots()
    {
        var serializer = Serializer();
        var first = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var second = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var third = Guid.Parse("33333333-3333-3333-3333-333333333333");
        var time = DateTimeOffset.Parse("2026-10-05T08:00:00Z");
        var metadata = new EventMetadata(first, time, "caresitter-api", "booking-1", "trace-1");
        var samples = new[]
        {
            ("notification-requested.v1.json", serializer.Create(new NotificationRequested(second, third, ["push"], "SYSTEM"), metadata)),
            ("payment-succeeded.v1.json", serializer.Create(new PaymentSucceeded(second, third, time), metadata)),
            ("meal-plan-selected.v1.json", serializer.Create(new MealPlanSelected(second, third), metadata))
        };
        foreach (var (file, envelope) in samples)
            Assert.Equal((await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "Snapshots", file))).Trim(), serializer.Serialize(envelope));
    }

    [Fact]
    public void Envelope_rejects_empty_identity_oversize_payload_and_non_utc_time()
    {
        var serializer = Serializer(1024);
        var meta = new EventMetadata(Guid.NewGuid(), DateTimeOffset.UtcNow, "api", "key");
        var data = new NotificationRequested(Guid.NewGuid(), Guid.NewGuid(), ["push"], "SYSTEM");
        Assert.Throws<InvalidDataException>(() => serializer.Create(data, meta with { EventId = Guid.Empty }));
        Assert.Throws<InvalidDataException>(() => serializer.Create(data, meta with { OccurredAt = DateTimeOffset.Now.ToOffset(TimeSpan.FromHours(7)) }));
        Assert.Throws<InvalidDataException>(() => serializer.Create(data with { TemplateKey = new string('a', 2000) }, meta));
    }

    [Fact]
    public void Registry_rejects_duplicate_wire_identity_and_schema_injection()
    {
        var registry = new EventTypeRegistry();
        registry.Add<PaymentSucceeded>("payment", 1, "payments");
        Assert.Throws<InvalidOperationException>(() => registry.Add<PaymentSucceeded>("payment", 1, "payments"));
        Assert.Throws<ArgumentException>(() => OutboxConfiguration.ValidateSchema("support; DROP TABLE x"));
    }

    [Fact]
    public void Configuration_rejects_bad_flags_poll_budget_and_short_lease()
    {
        var validator = new KafkaOptionsValidator();
        Assert.True(validator.Validate(null, new KafkaOptions { NotificationsEnabled = true }).Failed);
        Assert.True(validator.Validate(null, new KafkaOptions { Enabled = true, BootstrapServers = "kafka:9092", MaxPollIntervalMs = 5000 }).Failed);
        Assert.True(validator.Validate(null, new KafkaOptions { Enabled = true, BootstrapServers = "kafka:9092" }).Succeeded);
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["KAFKA_ENABLED"] = "maybe" }).Build();
        Assert.Throws<InvalidOperationException>(() => KafkaOptions.Read(config));
        config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["KAFKA_OUTBOX_LEASE_SECONDS"] = "5" }).Build();
        Assert.Throws<InvalidOperationException>(() => MessagingPersistenceOptions.Read(config));
    }

    [Fact]
    public void Relay_backoff_is_bounded_and_grows()
    {
        Assert.InRange(OutboxRelayWorker.RetryDelay(1).TotalSeconds, 2, 2.251);
        Assert.InRange(OutboxRelayWorker.RetryDelay(100).TotalSeconds, 300, 300.251);
    }

    [Fact]
    public void Dlq_configuration_resolves_overrides_and_rejects_a_source_topic_collision()
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["KAFKA_TOPIC_NOTIFICATIONS"] = "custom.notifications", ["KAFKA_TOPIC_NOTIFICATIONS_DLQ"] = "custom.quarantine" }).Build();
        var options = KafkaOptions.Read(config);
        Assert.Equal("custom.quarantine", options.GetDeadLetterTopic("custom.notifications"));
        Assert.Equal("new.domain.dlq", options.GetDeadLetterTopic("new.domain"));
        options.Enabled = true; options.BootstrapServers = "kafka:9092";
        options.NotificationsDlqTopic = options.PaymentsTopic;
        Assert.True(new KafkaOptionsValidator().Validate(null, options).Failed);
    }

    [Fact]
    public async Task Notification_redelivery_skips_a_channel_already_marked_sent()
    {
        var client = new FakeDeliveryClient();
        var sender = new FakeSender();
        var handler = new DeliverNotificationHandler(client, sender);
        var message = new NotificationRequested(Guid.NewGuid(), Guid.NewGuid(), ["push"], "SYSTEM");
        var context = new EventContext(Guid.NewGuid(), "notification", 1, "worker", "topic", 0, 0, null);
        Assert.Equal(HandlerOutcome.Success, (await handler.HandleAsync(message, context, default)).Outcome);
        Assert.Equal(HandlerOutcome.Success, (await handler.HandleAsync(message, context, default)).Outcome);
        Assert.Equal(1, sender.Count);
    }

    private sealed class FakeDeliveryClient : INotificationDeliveryClient
    {
        private bool _sent;
        public Task<DeliveryClaim> ClaimAsync(Guid eventId, Guid notificationId, Guid recipientId, string channel, CancellationToken ct) =>
            Task.FromResult(_sent ? new DeliveryClaim("Sent") : new DeliveryClaim("Acquired", Guid.NewGuid()));
        public Task<bool> CompleteAsync(Guid eventId, string channel, Guid token, bool success, string? failure, CancellationToken ct)
        { _sent = success; return Task.FromResult(true); }
    }
    private sealed class FakeSender : INotificationSender
    {
        public int Count;
        public Task<HandlerResult> SendAsync(string channel, DeliveryClaim claim, CancellationToken ct)
        { Count++; return Task.FromResult(HandlerResult.Success()); }
    }
}
