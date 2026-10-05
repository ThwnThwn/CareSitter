using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record GetAdminUserQuery(Guid UserId) : IRequest<Result<AdminUserResponse>>;
