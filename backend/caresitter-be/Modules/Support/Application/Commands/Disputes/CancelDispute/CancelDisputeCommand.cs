using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CancelDispute;

public sealed record CancelDisputeCommand(Guid DisputeId) : IRequest<Result<DisputeResponse>>;
