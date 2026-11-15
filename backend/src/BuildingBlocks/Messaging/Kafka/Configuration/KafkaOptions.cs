using Microsoft.Extensions.Configuration;

namespace CareSitter.Messaging.Kafka.Configuration;

/// <summary>Environment-only settings for transport, consumer budgets and flow cutovers.</summary>
public sealed class KafkaOptions
{
    public bool Enabled { get; set; }
    public string BootstrapServers { get; set; } = "";
    public string ClientId { get; set; } = "caresitter-api";
    public int DeliveryTimeoutMs { get; set; } = 10000;
    public int MaxMessageBytes { get; set; } = 65536;
    public int MaxRetries { get; set; } = 5;
    public int MaxPollIntervalMs { get; set; } = 300000;
    public int HandlerTimeoutMs { get; set; } = 30000;
    public int ShutdownTimeoutMs { get; set; } = 15000;
    public string ConsumerGroup { get; set; } = "notifications-v1";
    public string NotificationsTopic { get; set; } = "caresitter.notifications.events.v1";
    public string PaymentsTopic { get; set; } = "caresitter.payments.events.v1";
    public string NutritionTopic { get; set; } = "caresitter.nutrition.events.v1";
    public string? NotificationsDlqTopic { get; set; }
    public string? PaymentsDlqTopic { get; set; }
    public string? NutritionDlqTopic { get; set; }
    public bool NotificationsEnabled { get; set; }
    public bool PaymentsEnabled { get; set; }
    public bool NutritionEnabled { get; set; }

    /// <summary>Reads explicit environment keys; malformed values fail with the offending key.</summary>
    public static KafkaOptions Read(IConfiguration c) => new()
    {
        Enabled = ReadBool(c, "KAFKA_ENABLED", false),
        BootstrapServers = c["KAFKA_BOOTSTRAP_SERVERS"] ?? "",
        ClientId = c["KAFKA_CLIENT_ID"] ?? "caresitter-api",
        DeliveryTimeoutMs = ReadInt(c, "KAFKA_PRODUCER_DELIVERY_TIMEOUT_MS", 10000),
        MaxMessageBytes = ReadInt(c, "KAFKA_PRODUCER_MAX_MESSAGE_BYTES", 65536),
        MaxRetries = ReadInt(c, "KAFKA_CONSUMER_MAX_RETRIES", 5),
        MaxPollIntervalMs = ReadInt(c, "KAFKA_CONSUMER_MAX_POLL_INTERVAL_MS", 300000),
        HandlerTimeoutMs = ReadInt(c, "KAFKA_CONSUMER_HANDLER_TIMEOUT_MS", 30000),
        ShutdownTimeoutMs = ReadInt(c, "KAFKA_CONSUMER_SHUTDOWN_TIMEOUT_MS", 15000),
        ConsumerGroup = c["KAFKA_CONSUMER_GROUP"] ?? "notifications-v1",
        NotificationsTopic = c["KAFKA_TOPIC_NOTIFICATIONS"] ?? "caresitter.notifications.events.v1",
        PaymentsTopic = c["KAFKA_TOPIC_PAYMENTS"] ?? "caresitter.payments.events.v1",
        NutritionTopic = c["KAFKA_TOPIC_NUTRITION"] ?? "caresitter.nutrition.events.v1",
        NotificationsDlqTopic = c["KAFKA_TOPIC_NOTIFICATIONS_DLQ"],
        PaymentsDlqTopic = c["KAFKA_TOPIC_PAYMENTS_DLQ"],
        NutritionDlqTopic = c["KAFKA_TOPIC_NUTRITION_DLQ"],
        NotificationsEnabled = ReadBool(c, "KAFKA_FLOW_NOTIFICATIONS_ENABLED", false),
        PaymentsEnabled = ReadBool(c, "KAFKA_FLOW_PAYMENTS_ENABLED", false),
        NutritionEnabled = ReadBool(c, "KAFKA_FLOW_NUTRITION_ENABLED", false)
    };

    /// <summary>Resolves an explicit domain DLQ override, or the convention for a newly registered topic.</summary>
    public string GetDeadLetterTopic(string sourceTopic) =>
        (sourceTopic == NotificationsTopic ? NotificationsDlqTopic :
         sourceTopic == PaymentsTopic ? PaymentsDlqTopic :
         sourceTopic == NutritionTopic ? NutritionDlqTopic : null) ?? sourceTopic + ".dlq";

    /// <summary>Parses a boolean setting without silently treating invalid input as disabled.</summary>
    public static bool ReadBool(IConfiguration c, string key, bool fallback) =>
        c[key] is not { } value ? fallback : bool.TryParse(value, out var parsed) ? parsed :
        throw new InvalidOperationException($"{key} must be true or false.");

    /// <summary>Parses an integer setting and reports invalid environment input.</summary>
    public static int ReadInt(IConfiguration c, string key, int fallback) =>
        c[key] is not { } value ? fallback : int.TryParse(value, out var parsed) ? parsed :
        throw new InvalidOperationException($"{key} must be an integer.");
}
