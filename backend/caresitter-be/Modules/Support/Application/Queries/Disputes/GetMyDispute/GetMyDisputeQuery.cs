using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record GetMyDisputeQuery(Guid DisputeId) : IRequest<Result<DisputeResponse>>;
