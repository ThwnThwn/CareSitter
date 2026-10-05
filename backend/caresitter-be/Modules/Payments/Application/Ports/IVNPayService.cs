using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application;

public interface IVNPayService
{
    string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options,
        string? bookingCustomerName = null);
    bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options);
    Task<VNPayQueryResult> QueryTransactionAsync(PaymentIntent intent, VNPayOptions options,
        CancellationToken ct = default);
}
