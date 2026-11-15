using System.Text.Json;
using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application;

public interface IPayOSService
{
    Task<PayOSPaymentLink> CreateLinkAsync(PaymentIntent intent, CancellationToken ct = default);
    Task<PaymentProviderQuery> QueryAsync(PaymentIntent intent, CancellationToken ct = default);
    bool VerifyWebhook(JsonElement payload);
}

public interface IPaymentStatusGateway
{
    Task<PaymentProviderQuery> QueryAsync(PaymentIntent intent, CancellationToken ct = default);
}
