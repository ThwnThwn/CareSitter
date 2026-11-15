using MediatR;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentProviderResponse(string Code, string Name, string Description, bool Enabled);
public sealed record ListPaymentProvidersQuery : IRequest<IReadOnlyList<PaymentProviderResponse>>;
internal sealed class ListPaymentProvidersQueryHandler(IOptions<PayOSOptions> payOS, IOptions<VNPayOptions> vnPay)
    : IRequestHandler<ListPaymentProvidersQuery, IReadOnlyList<PaymentProviderResponse>>
{
    public Task<IReadOnlyList<PaymentProviderResponse>> Handle(ListPaymentProvidersQuery request, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<PaymentProviderResponse>>(new PaymentProviderResponse[]
        {
            new("PAYOS", "payOS", "Chuyển khoản ngân hàng qua VietQR", payOS.Value.Enabled),
            new("VNPAY", "VNPAY", "Thanh toán qua ngân hàng, ví hoặc thẻ",
                !string.IsNullOrWhiteSpace(vnPay.Value.TmnCode) && !string.IsNullOrWhiteSpace(vnPay.Value.HashSecret))
        });
}
