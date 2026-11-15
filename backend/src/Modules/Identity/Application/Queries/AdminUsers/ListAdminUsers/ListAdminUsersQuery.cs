using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record ListAdminUsersQuery(
    string? Query, string? Role, string? Status, int Page, int PageSize)
    : IRequest<Result<IdentityPage<AdminUserResponse>>>;
