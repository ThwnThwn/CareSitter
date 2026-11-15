using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application;

public sealed record VNPayQueryResult(VNPayQueryState State, string? TransactionId,
    string ResponseCode, string? TransactionStatus, string RawPayload, string? Message);
