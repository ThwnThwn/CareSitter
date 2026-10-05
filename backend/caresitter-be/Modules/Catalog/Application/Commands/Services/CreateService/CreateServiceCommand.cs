using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record CreateServiceCommand(
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool IsActive) : IRequest<Result<AdminServiceResponse>>;
