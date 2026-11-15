using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record SetServiceActiveCommand(
    Guid ServiceId,
    bool IsActive) : IRequest<Result<AdminServiceResponse>>;
