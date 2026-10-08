using System.Text.Json;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public interface IPayOSPaymentPortal
{
    Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(Guid bookingId, Guid userId,
        CancellationToken ct = default);
    Task RefreshAsync(Guid intentId, CancellationToken ct = default);
    Task<PayOSWebhookOutcome> ProcessWebhookAsync(JsonElement payload, CancellationToken ct = default);
    Task<string> GetReturnUrlAsync(string? orderCode, CancellationToken ct = default);
}

public sealed record PayOSWebhookOutcome(int StatusCode, string Message);
