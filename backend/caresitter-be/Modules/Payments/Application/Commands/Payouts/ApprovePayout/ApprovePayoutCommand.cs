using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;

public sealed record ApprovePayoutCommand(Guid PayoutId)
    : IRequest<Result<PayoutResponse>>;
