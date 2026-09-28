using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.RejectPayout;

public sealed record RejectPayoutCommand(Guid PayoutId, string? Reason)
    : IRequest<Result<PayoutResponse>>;
