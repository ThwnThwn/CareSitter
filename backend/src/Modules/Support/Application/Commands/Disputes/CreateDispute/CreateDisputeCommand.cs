using CareSitter.SharedKernel.Results;
using MediatR;
using CareSitter.SharedKernel.Modules;

namespace CareSitter.Modules.Support.Application.Commands.CreateDispute;

public sealed record CreateDisputeCommand(
    Guid BookingId, string? Reason, string? Description)
    : IRequest<Result<DisputeResponse>>, IAtomicModuleCommand
{
    public string TransactionGroup => "dispute";
    public string LockKey => BookingId.ToString();
}
