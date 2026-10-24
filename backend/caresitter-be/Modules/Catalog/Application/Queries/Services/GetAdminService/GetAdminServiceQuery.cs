using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record GetAdminServiceQuery(Guid ServiceId)
    : IRequest<Result<AdminServiceResponse>>;
