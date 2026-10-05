using CareSitter.Modules.Payments.Application;

namespace CareSitter.Modules.Payments.Controllers;

public sealed record ResolvePaymentReviewRequest(
    bool Succeeded, string Reason, string? ProviderTransactionId = null);
