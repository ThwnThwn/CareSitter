using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record SetAdminUserRolesCommand(Guid UserId, string[]? Roles)
    : IRequest<Result<AdminUserResponse>>;
