using System.Globalization;
using System.Net;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

public interface IVNPayRefundGateway
{
    Task<VNPayRefundResult> SubmitAsync(VNPayFullRefundRequest request,
        CancellationToken ct = default);
    Task<VNPayRefundResult> QueryAsync(VNPayFullRefundRequest request,
        string queryRequestId, DateTimeOffset queryCreatedAt, CancellationToken ct = default);
}
