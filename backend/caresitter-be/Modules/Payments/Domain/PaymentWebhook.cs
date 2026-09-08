using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

/// <summary>
/// Webhook nhan tu provider thanh toan. Idempotent theo (provider, provider_event_id).
/// Map sang bang payment_webhooks. Bang KHONG co updated_at.
/// </summary>
public sealed class PaymentWebhook : Entity
{
    private PaymentWebhook() { } // EF

    private PaymentWebhook(
        Guid id,
        string provider,
        string providerEventId,
        string? eventType,
        string? payload)
    {
        Id = id;
        Provider = provider;
        ProviderEventId = providerEventId;
        EventType = eventType;
        Payload = payload;
        Status = "RECEIVED";
    }

    /// <summary>Allowed values: 'VNPAY', 'MOMO', 'CARD'.</summary>
    public string Provider { get; private set; } = null!;

    public string ProviderEventId { get; private set; } = null!;
    public string? EventType { get; private set; }
    public string? Payload { get; private set; }
    public DateTimeOffset? ProcessedAt { get; private set; }

    /// <summary>Allowed values: 'RECEIVED', 'PROCESSED', 'FAILED'.</summary>
    public string Status { get; private set; } = null!;

    public static Result<PaymentWebhook> Create(
        string provider,
        string providerEventId,
        string? eventType = null,
        string? payload = null)
    {
        if (string.IsNullOrWhiteSpace(provider))
            return Error.Validation("webhook.provider", "provider khong duoc rong.");
        if (string.IsNullOrWhiteSpace(providerEventId))
            return Error.Validation("webhook.provider_event_id", "provider_event_id khong duoc rong.");

        return new PaymentWebhook(Guid.NewGuid(), provider, providerEventId, eventType, payload);
    }

    public Result MarkProcessed()
    {
        if (Status != "RECEIVED")
            return Error.Conflict("webhook.status", $"Khong the chuyen {Status} -> PROCESSED.");
        Status = "PROCESSED";
        ProcessedAt = DateTimeOffset.UtcNow;
        return Result.Success();
    }

    public Result MarkFailed()
    {
        if (Status != "RECEIVED")
            return Error.Conflict("webhook.status", $"Khong the chuyen {Status} -> FAILED.");
        Status = "FAILED";
        ProcessedAt = DateTimeOffset.UtcNow;
        return Result.Success();
    }
}
