using System.Globalization;
using System.Net;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record VNPayRefundResult(VNPayRefundState State, string Code,
    string? ProviderResponseId = null, string? ProviderRefundId = null,
    string? TransactionStatus = null, string? RawPayload = null);
