using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record SetAdminUserStatusCommand(Guid UserId, string Status)
    : IRequest<Result<AdminUserResponse>>;
