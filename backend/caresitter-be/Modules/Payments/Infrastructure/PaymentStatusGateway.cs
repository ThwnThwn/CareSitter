using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentStatusGateway(IVNPayService vnPay, IPayOSService payOS,
    IOptions<VNPayOptions> options) : IPaymentStatusGateway
{
    public async Task<PaymentProviderQuery> QueryAsync(PaymentIntent intent, CancellationToken ct = default)
    {
        if (intent.Provider == "PAYOS") return await payOS.QueryAsync(intent, ct);
        if (intent.Provider != "VNPAY")
            return new(PaymentProviderState.Unknown, null, "{}", "Cổng thanh toán chưa hỗ trợ đối soát.");
        var result = await vnPay.QueryTransactionAsync(intent, options.Value, ct);
        return new(result.State switch
        {
            VNPayQueryState.Succeeded => PaymentProviderState.Succeeded,
            VNPayQueryState.Processing => PaymentProviderState.Processing,
            VNPayQueryState.Failed => PaymentProviderState.Failed,
            VNPayQueryState.NotFound => PaymentProviderState.NotFound,
            _ => PaymentProviderState.Unknown
        }, result.TransactionId, result.RawPayload, result.Message);
    }
}
