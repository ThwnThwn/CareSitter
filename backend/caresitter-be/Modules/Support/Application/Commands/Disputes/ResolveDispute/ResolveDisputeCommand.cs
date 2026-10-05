using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.ResolveDispute;

public sealed record ResolveDisputeCommand(Guid DisputeId, string Decision,
    long? RefundAmount, long? CaregiverPenaltyAmount)
    : IRequest<Result<DisputeResponse>>;
