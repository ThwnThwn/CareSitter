using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentIntentResponse(
    Guid Id, Guid BookingId, Guid CustomerId, string Provider, long Amount,
    string Currency, string Status, string? ProviderTransactionId,
    string IdempotencyKey, DateTimeOffset CreatedAt,
    string? PaymentUrl = null, string? ProviderOrderRef = null);
