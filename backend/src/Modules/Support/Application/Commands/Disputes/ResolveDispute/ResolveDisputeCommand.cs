using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using MediatR;
using CareSitter.SharedKernel.Modules;

namespace CareSitter.Modules.Support.Application.Commands.ResolveDispute;

public sealed record ResolveDisputeCommand(Guid DisputeId, string Decision,
    long? RefundAmount, long? CaregiverPenaltyAmount, DisputeQuote? ExpectedQuote = null)
    : IRequest<Result<DisputeResponse>>, IAtomicModuleCommand
{
    public string TransactionGroup => "dispute";
    public string LockKey => DisputeId.ToString();
}
