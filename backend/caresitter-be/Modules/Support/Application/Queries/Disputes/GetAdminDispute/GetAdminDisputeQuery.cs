using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record GetAdminDisputeQuery(Guid DisputeId) : IRequest<Result<DisputeResponse>>;
