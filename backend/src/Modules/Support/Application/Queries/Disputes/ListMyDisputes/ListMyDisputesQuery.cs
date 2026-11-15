using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListMyDisputesQuery : IRequest<Result<IReadOnlyList<DisputeResponse>>>;
