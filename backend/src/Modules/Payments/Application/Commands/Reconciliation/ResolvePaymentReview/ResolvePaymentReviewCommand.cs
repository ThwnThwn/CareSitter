using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ResolvePaymentReviewCommand(
    Guid IntentId, bool Succeeded, string Reason, string? ProviderTransactionId)
    : IRequest<Result<PaymentReviewResolution>>;
