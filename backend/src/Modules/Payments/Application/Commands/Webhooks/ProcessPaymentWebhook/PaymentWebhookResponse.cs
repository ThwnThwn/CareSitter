using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentWebhookResponse(string Status, Guid? WebhookId = null);
