using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.CreatePayout;

public sealed record CreatePayoutCommand(
    long Amount,
    string BankName,
    string AccountHolderName,
    string AccountNumber,
    string? BodyIdempotencyKey,
    string? HeaderIdempotencyKey) : IRequest<Result<CreatePayoutResult>>
{
    public string? ResolveIdempotencyKey()
    {
        var value = string.IsNullOrWhiteSpace(BodyIdempotencyKey)
            ? HeaderIdempotencyKey
            : BodyIdempotencyKey;
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
