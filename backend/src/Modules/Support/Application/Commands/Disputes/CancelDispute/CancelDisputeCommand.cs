using CareSitter.SharedKernel.Results;
using MediatR;
using CareSitter.SharedKernel.Modules;

namespace CareSitter.Modules.Support.Application.Commands.CancelDispute;

public sealed record CancelDisputeCommand(Guid DisputeId) : IRequest<Result<DisputeResponse>>, IAtomicModuleCommand
{
    public string TransactionGroup => "dispute";
    public string LockKey => DisputeId.ToString();
}
