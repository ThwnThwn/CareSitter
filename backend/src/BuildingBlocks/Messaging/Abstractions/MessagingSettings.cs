namespace CareSitter.Messaging.Abstractions;

/// <summary>Validated, immutable feature flags exposed to applications without Kafka dependencies.</summary>
public sealed record MessagingSettings(bool Enabled, bool NotificationsEnabled,
    bool PaymentsEnabled, bool NutritionEnabled, string Producer);
