using CareSitter.Modules.Payments.Application;

namespace CareSitter.Modules.Payments.Controllers;

public sealed record WebhookRequest(
    string Provider,
    string ProviderEventId,
    string? EventType = null,
    string? ProviderTransactionId = null,
    string? ProviderOrderRef = null,
    string? Payload = null);
