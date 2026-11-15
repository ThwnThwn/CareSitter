using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;

namespace CareSitter.Messaging.Kafka.Configuration;

/// <summary>Rejects invalid startup settings and retry budgets that can evict the consumer.</summary>
public sealed class KafkaOptionsValidator : IValidateOptions<KafkaOptions>
{
    /// <summary>Validates flags even when disabled and transport settings when enabled.</summary>
    public ValidateOptionsResult Validate(string? name, KafkaOptions o)
    {
        var errors = new List<string>();
        if (!o.Enabled)
        {
            if (o.NotificationsEnabled || o.PaymentsEnabled || o.NutritionEnabled)
                errors.Add("KAFKA_ENABLED must be true when any KAFKA_FLOW_*_ENABLED flag is true.");
            return errors.Count == 0 ? ValidateOptionsResult.Success : ValidateOptionsResult.Fail(errors);
        }
        if (string.IsNullOrWhiteSpace(o.BootstrapServers)) errors.Add("KAFKA_BOOTSTRAP_SERVERS is required.");
        if (string.IsNullOrWhiteSpace(o.ClientId)) errors.Add("KAFKA_CLIENT_ID is required.");
        if (string.IsNullOrWhiteSpace(o.ConsumerGroup)) errors.Add("KAFKA_CONSUMER_GROUP is required.");
        if (o.DeliveryTimeoutMs is < 1000 or > 60000) errors.Add("KAFKA_PRODUCER_DELIVERY_TIMEOUT_MS must be 1000..60000.");
        if (o.MaxMessageBytes is < 1024 or > 1048576) errors.Add("KAFKA_PRODUCER_MAX_MESSAGE_BYTES must be 1024..1048576.");
        if (o.MaxRetries is < 0 or > 8) errors.Add("KAFKA_CONSUMER_MAX_RETRIES must be 0..8.");
        if (o.HandlerTimeoutMs is < 100 or > 60000) errors.Add("KAFKA_CONSUMER_HANDLER_TIMEOUT_MS must be 100..60000.");
        if (o.ShutdownTimeoutMs is < 1000 or > 60000) errors.Add("KAFKA_CONSUMER_SHUTDOWN_TIMEOUT_MS must be 1000..60000.");
        var mainTopics = new[] { o.NotificationsTopic, o.PaymentsTopic, o.NutritionTopic };
        var allTopics = mainTopics.Concat(mainTopics.Select(o.GetDeadLetterTopic)).ToArray();
        foreach (var topic in allTopics)
            if (!Regex.IsMatch(topic, "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,239}$") || topic is "." or "..")
                errors.Add("KAFKA_TOPIC_* values must be valid topic names with room for the .dlq suffix.");
        if (allTopics.Distinct().Count() != 6)
            errors.Add("KAFKA_TOPIC_* and KAFKA_TOPIC_*_DLQ values must be distinct.");
        // Every handler attempt, bounded backoff and one DLQ publish fit inside the poll interval.
        var attempts = Math.Clamp(o.MaxRetries, 0, 8) + 1;
        var backoff = Enumerable.Range(0, Math.Clamp(o.MaxRetries, 0, 8))
            .Sum(i => Math.Min(16000, 1000 * (1 << i)) + 250);
        if (o.MaxPollIntervalMs <= (long)attempts * o.HandlerTimeoutMs + backoff + o.DeliveryTimeoutMs + 10000)
            errors.Add("KAFKA_CONSUMER_MAX_POLL_INTERVAL_MS must exceed the handler/retry/DLQ budget by 10000 ms.");
        return errors.Count == 0 ? ValidateOptionsResult.Success : ValidateOptionsResult.Fail(errors);
    }
}
